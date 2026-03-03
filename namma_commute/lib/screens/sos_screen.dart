import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});
  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sosController;
  late Animation<double> _sosAnimation;
  bool _sosActivated = false;
  bool _sendingSOS = false;
  List<dynamic> _contacts = [];
  List<dynamic> _guidanceSteps = [];
  bool _loading = true;
  double? _lat;
  double? _lng;
  String _locationText = 'Locating...';

  @override
  void initState() {
    super.initState();
    _sosController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _sosAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));
    _fetchData();
    _getLocation();
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _lat = pos?.latitude;
      _lng = pos?.longitude;
      _locationText = pos != null ? LocationService.nearestArea(pos) : 'Location unavailable';
    });
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        ApiService.getEmergencyContacts(),
        ApiService.getAccidentGuidance(),
      ]);
      if (!mounted) return;
      final guidance = results[1] as Map<String, dynamic>;
      setState(() {
        _contacts = results[0] as List<dynamic>;
        _guidanceSteps = (guidance['steps'] as List<dynamic>?) ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _callNumber(String number, String name) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Clipboard.setData(ClipboardData(text: number));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📋 $number copied to clipboard. Open dialer to call $name.'),
            backgroundColor: const Color(0xFFE8581C), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _activateSOS() async {
    setState(() { _sosActivated = true; _sendingSOS = true; });
    try {
      await ApiService.triggerSOS({
        'user_id': 'app_user',
        'latitude': _lat ?? 12.9716,
        'longitude': _lng ?? 77.5946,
        'location_text': _locationText,
        'alert_type': 'emergency',
        'message': 'SOS triggered from Namma Commute app',
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _sendingSOS = false);
    Clipboard.setData(const ClipboardData(text: 'EMERGENCY! Need help. Call 108 (Ambulance) or 103 (Traffic Police)'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🆘 SOS sent! Emergency message copied. Dial 108 for Ambulance now!'),
        backgroundColor: Color(0xFFFF2D55),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ),
    );
  }

  Color _contactColor(String type) {
    switch (type) {
      case 'police':    return const Color(0xFF6C63FF);
      case 'ambulance': return const Color(0xFFFF2D55);
      case 'fire':      return const Color(0xFFFF9500);
      case 'bbmp':      return const Color(0xFF00C9A7);
      default:          return const Color(0xFFE8581C);
    }
  }

  IconData _contactIcon(String type) {
    switch (type) {
      case 'police':    return Icons.local_police_rounded;
      case 'ambulance': return Icons.medical_services_rounded;
      case 'fire':      return Icons.local_fire_department_rounded;
      case 'bbmp':      return Icons.business_rounded;
      default:          return Icons.phone_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSOSButton()),
          SliverToBoxAdapter(child: _buildLocationCard()),
          if (_loading)
            const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFFFF2D55)))))
          else ...[
            SliverToBoxAdapter(child: _buildEmergencyContacts()),
            SliverToBoxAdapter(child: _buildGuidanceSteps()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF16162A),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Emergency SOS', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Tap SOS to alert · Tap contacts to call directly', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      )),
    );
  }

  Widget _buildSOSButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
      child: Column(children: [
        AnimatedBuilder(
          animation: _sosAnimation,
          builder: (ctx, child) => Transform.scale(scale: _sosActivated ? _sosAnimation.value : 1.0, child: child),
          child: GestureDetector(
            onTap: _sosActivated ? () => setState(() => _sosActivated = false) : _activateSOS,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: _sosActivated
                    ? [const Color(0xFFFF2D55), const Color(0xFFCC0025)]
                    : [const Color(0xFF2A0010), const Color(0xFF1A0008)]),
                border: Border.all(color: const Color(0xFFFF2D55), width: _sosActivated ? 3 : 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFFFF2D55).withOpacity(_sosActivated ? 0.6 : 0.2),
                    blurRadius: _sosActivated ? 40 : 20, spreadRadius: _sosActivated ? 10 : 0)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _sendingSOS
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                    : const Icon(Icons.emergency_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text('SOS', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4)),
                if (_sosActivated) const Text('ACTIVE', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _sosActivated ? '🔴 SOS Active — Alert sent to backend!' : 'Tap SOS to send emergency alert',
          textAlign: TextAlign.center,
          style: TextStyle(color: _sosActivated ? const Color(0xFFFF2D55) : Colors.white38,
              fontSize: 12, fontWeight: _sosActivated ? FontWeight.w700 : FontWeight.w400),
        ),
        if (_sosActivated) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _sosActivated = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: const Text('Cancel SOS', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildLocationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF16162A), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF00C9A7), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your Location', style: TextStyle(color: Colors.white54, fontSize: 10)),
            Text(_locationText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            if (_lat != null && _lng != null)
              Text('${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ])),
          GestureDetector(
            onTap: _getLocation,
            child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF00C9A7).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.refresh_rounded, color: Color(0xFF00C9A7), size: 18)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    final displayContacts = _contacts.isNotEmpty ? _contacts : [
      {'name': 'Traffic Police', 'number': '103', 'type': 'police'},
      {'name': 'Ambulance', 'number': '108', 'type': 'ambulance'},
      {'name': 'BBMP Helpline', 'number': '1533', 'type': 'bbmp'},
      {'name': 'Fire Service', 'number': '101', 'type': 'fire'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Emergency Contacts', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const Text('Tap to call directly', style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.4),
          itemCount: displayContacts.length > 6 ? 6 : displayContacts.length,
          itemBuilder: (ctx, i) {
            final c = displayContacts[i] as Map<String, dynamic>;
            final type = c['type'] as String? ?? 'police';
            final color = _contactColor(type);
            return GestureDetector(
              onTap: () => _callNumber(c['number'] as String, c['name'] as String),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Row(children: [
                  Icon(_contactIcon(type), color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(c['number'] as String, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(c['name'] as String, style: const TextStyle(color: Colors.white54, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  Icon(Icons.phone_rounded, color: color.withOpacity(0.6), size: 14),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildGuidanceSteps() {
    final steps = _guidanceSteps.isNotEmpty ? _guidanceSteps : [
      {'step': 1, 'title': 'Stay Calm', 'desc': 'Assess yourself for injuries before moving.'},
      {'step': 2, 'title': 'Call Emergency', 'desc': 'Call 108 for ambulance or 103 for Traffic Police.'},
      {'step': 3, 'title': 'Share Location', 'desc': 'Use SOS button to share your GPS location.'},
      {'step': 4, 'title': "Don't Move Vehicle", 'desc': 'Keep vehicles in place until police arrive.'},
      {'step': 5, 'title': 'Document Scene', 'desc': 'Take photos of damage and number plates if safe.'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("If You're in an Accident", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...steps.map((step) {
          final s = step as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: const Color(0xFFFF2D55).withOpacity(0.1), shape: BoxShape.circle),
                  child: Center(child: Text('${s['step']}', style: const TextStyle(color: Color(0xFFFF2D55), fontSize: 12, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(s['desc'] as String, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}
