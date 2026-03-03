import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedType;
  String? _selectedArea;
  String _description = '';
  String _severity = 'moderate';
  bool _submitted = false;
  bool _submitting = false;
  bool _loadingReports = true;
  List<dynamic> _communityReports = [];
  String? _locationText;
  Timer? _refreshTimer;
  final _descCtrl = TextEditingController();

  final List<Map<String, dynamic>> _reportTypes = [
    {'type': 'accident',      'icon': '🚗', 'label': 'Accident',       'color': Color(0xFFFF2D55)},
    {'type': 'pothole',       'icon': '🕳️', 'label': 'Pothole',        'color': Color(0xFFFF9500)},
    {'type': 'signal_issue',  'icon': '🚦', 'label': 'Signal Issue',   'color': Color(0xFFFFCC00)},
    {'type': 'waterlogging',  'icon': '🌊', 'label': 'Waterlogging',   'color': Color(0xFF6C63FF)},
    {'type': 'road_block',    'icon': '🚧', 'label': 'Road Block',     'color': Color(0xFFFF6B9D)},
    {'type': 'no_lighting',   'icon': '💡', 'label': 'No Lighting',    'color': Color(0xFF00C9A7)},
  ];

  final List<String> _areas = [
    'Koramangala', 'Whitefield', 'Indiranagar', 'Silk Board',
    'Marathahalli', 'Hebbal', 'Electronic City', 'Jayanagar',
    'Rajajinagar', 'Yeshwanthpur', 'BTM Layout', 'HSR Layout',
  ];

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _getLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchReports());
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _getLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (pos != null) {
      setState(() {
        _locationText = LocationService.nearestArea(pos);
        _selectedArea = _locationText;
      });
    }
  }

  Future<void> _fetchReports() async {
    try {
      final reports = await ApiService.getCommunityReports();
      if (!mounted) return;
      setState(() { _communityReports = reports; _loadingReports = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingReports = false);
    }
  }

  Future<void> _submitReport() async {
    if (_selectedType == null || _selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select type and area'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.submitReport({
        'type': _selectedType,
        'location': _selectedArea,
        'area': _selectedArea,
        'description': _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
        'severity': _severity,
      });
      if (!mounted) return;
      setState(() { _submitted = true; _submitting = false; });
      _fetchReports();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _upvote(int id) async {
    try {
      await ApiService.upvoteReport(id);
      _fetchReports();
    } catch (_) {}
  }

  Color _typeColor(String type) {
    for (final t in _reportTypes) { if (t['type'] == type) return t['color'] as Color; }
    return const Color(0xFFE8581C);
  }

  String _typeIcon(String type) {
    for (final t in _reportTypes) { if (t['type'] == type) return t['icon'] as String; }
    return '⚠️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildTypeSelector()),
        SliverToBoxAdapter(child: _buildAreaSelector()),
        SliverToBoxAdapter(child: _buildSeveritySelector()),
        SliverToBoxAdapter(child: _buildDescField()),
        SliverToBoxAdapter(child: _buildSubmitButton()),
        SliverToBoxAdapter(child: _buildCommunityReports()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF16162A),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report an Issue', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('Help your fellow Bengalureans navigate better', style: TextStyle(color: Colors.white38, fontSize: 12)),
          if (_locationText != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFF00C9A7), size: 14),
              const SizedBox(width: 4),
              Text('Near: $_locationText', style: const TextStyle(color: Color(0xFF00C9A7), fontSize: 11)),
            ]),
          ],
        ]),
      )),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What are you reporting?', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3),
          itemCount: _reportTypes.length,
          itemBuilder: (ctx, i) {
            final type = _reportTypes[i];
            final isSelected = _selectedType == type['type'];
            final color = type['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type['type'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.08), width: isSelected ? 1.5 : 1),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(type['icon'] as String, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(type['label'] as String, style: TextStyle(color: isSelected ? color : Colors.white54,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildAreaSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Select Area', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(height: 36, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _areas.length,
          itemBuilder: (ctx, i) {
            final isSelected = _selectedArea == _areas[i];
            return GestureDetector(
              onTap: () => setState(() => _selectedArea = _areas[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8581C).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFFE8581C) : Colors.white.withOpacity(0.1)),
                ),
                child: Text(_areas[i], style: TextStyle(
                    color: isSelected ? const Color(0xFFE8581C) : Colors.white54,
                    fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _buildSeveritySelector() {
    final levels = [
      {'val': 'low', 'label': 'Low', 'color': Color(0xFF34C759)},
      {'val': 'moderate', 'label': 'Moderate', 'color': Color(0xFFFFCC00)},
      {'val': 'high', 'label': 'High', 'color': Color(0xFFFF9500)},
      {'val': 'critical', 'label': 'Critical', 'color': Color(0xFFFF2D55)},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Severity', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: levels.map((l) {
          final isSelected = _severity == l['val'];
          final color = l['color'] as Color;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _severity = l['val'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.08)),
              ),
              child: Text(l['label'] as String, textAlign: TextAlign.center,
                  style: TextStyle(color: isSelected ? color : Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ));
        }).toList()),
      ]),
    );
  }

  Widget _buildDescField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Description (Optional)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(hintText: 'Describe the issue briefly...',
                hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none,
                contentPadding: EdgeInsets.all(14)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: _submitting ? null : _submitReport,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFE8581C), Color(0xFFFF8C42)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: const Color(0xFFE8581C).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: _submitting
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Submit Report', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ]),
        ),
      ),
    );
  }

  Widget _buildCommunityReports() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Community Reports', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Real reports from Bengalureans', style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 12),
        _loadingReports
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8581C)))
            : _communityReports.isEmpty
                ? const Text('No reports yet. Be the first!', style: TextStyle(color: Colors.white38, fontSize: 13))
                : Column(children: _communityReports.take(5).map((r) => _buildReportCard(r as Map<String, dynamic>)).toList()),
      ]),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final type = report['type'] as String? ?? 'accident';
    final color = _typeColor(type);
    final upvotes = report['upvotes'] as int? ?? 0;
    final id = report['id'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF16162A), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Text(_typeIcon(type), style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(report['location'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('${report['area']} · ${report['status']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () => _upvote(id),
          child: Column(children: [
            Icon(Icons.thumb_up_rounded, color: color, size: 16),
            const SizedBox(height: 2),
            Text('$upvotes', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSuccess() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100,
            decoration: BoxDecoration(color: const Color(0xFF00C9A7).withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00C9A7), size: 54)),
        const SizedBox(height: 24),
        Text('Report Submitted!', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text('Thanks for helping Bengalureans navigate better!\nYour report is now live.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6)),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => setState(() { _submitted = false; _selectedType = null; _descCtrl.clear(); }),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8581C),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Report Another', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),
    ));
  }
}
