import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class LiveTrafficScreen extends StatefulWidget {
  const LiveTrafficScreen({super.key});
  @override
  State<LiveTrafficScreen> createState() => _LiveTrafficScreenState();
}

class _LiveTrafficScreenState extends State<LiveTrafficScreen> {
  String _selectedFilter = 'All';
  bool _loading = true;
  bool _hasError = false;
  List<dynamic> _incidents = [];
  Map<String, dynamic> _summary = {};
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  final List<String> _filters = ['All', 'critical', 'high', 'accident', 'flood', 'construction'];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        ApiService.getTrafficIncidents(),
        ApiService.getTrafficSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _incidents = results[0] as List<dynamic>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
        _hasError = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _loading = false; });
    }
  }

  List<dynamic> get _filtered {
    if (_selectedFilter == 'All') return _incidents;
    return _incidents.where((i) =>
      i['severity'] == _selectedFilter || i['type'] == _selectedFilter
    ).toList();
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return const Color(0xFFFF2D55);
      case 'high':     return const Color(0xFFFF9500);
      case 'moderate': return const Color(0xFFFFCC00);
      default:         return const Color(0xFF34C759);
    }
  }

  String _typeIcon(String type) {
    switch (type) {
      case 'accident':     return '🚗';
      case 'construction': return '🚧';
      case 'flood':        return '🌊';
      case 'event':        return '🎭';
      case 'signal':       return '🚦';
      case 'pothole':      return '🕳️';
      default:             return '⚠️';
    }
  }

  void _showRouteInfo(Map<String, dynamic> incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Avoid — ${incident['location']}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(incident['description'] as String? ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 16),
          const Text('💡 Alternative routes:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          const Text('• Use Outer Ring Road via Marathahalli\n• Take NICE Road heading south\n• Metro recommended if available',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.6)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it', style: TextStyle(color: Color(0xFFE8581C)))),
        ],
      ),
    );
  }

  Future<void> _upvoteIncident(int id) async {
    try {
      await ApiService.upvoteIncident(id);
      _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('👍 Thanks for confirming this incident!'),
            backgroundColor: Color(0xFFE8581C), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {}
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16162A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _QuickReportSheet(onSubmit: (data) async {
        Navigator.pop(ctx);
        try {
          await ApiService.createIncident(data);
          _fetchData();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Incident reported! Thank you.'),
                backgroundColor: Color(0xFF34C759), behavior: SnackBarBehavior.floating),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(children: [
        _buildHeader(),
        _buildSummaryBar(),
        _buildFilterRow(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8581C)))
              : _hasError
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('📡', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text('Could not load incidents', style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _fetchData,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8581C)),
                          child: const Text('Retry', style: TextStyle(color: Colors.white))),
                    ]))
                  : filtered.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('✅', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No $_selectedFilter incidents right now',
                              style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _fetchData,
                          color: const Color(0xFFE8581C),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _buildIncidentCard(filtered[i] as Map<String, dynamic>),
                          ),
                        ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportSheet,
        backgroundColor: const Color(0xFFE8581C),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text('Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF16162A),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06)))),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Live Traffic', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text('${_incidents.length} active incidents · Bengaluru',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFFF2D55).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Text('● LIVE', style: TextStyle(color: Color(0xFFFF2D55), fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      )),
    );
  }

  Widget _buildSummaryBar() {
    if (_summary.isEmpty) return const SizedBox.shrink();
    final index = _summary['traffic_index'] as int? ?? 50;
    final color = index > 65 ? const Color(0xFF34C759) : index > 45 ? const Color(0xFFFFCC00) : const Color(0xFFFF2D55);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.analytics_rounded, color: color, size: 16),
        const SizedBox(width: 8),
        Text('Traffic Index: $index/100', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        const Spacer(),
        Text('${_summary['total_active_incidents'] ?? 0} incidents · ${_summary['critical_incidents'] ?? 0} critical',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 44, margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final isSelected = _selectedFilter == _filters[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = _filters[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8581C) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? const Color(0xFFE8581C) : Colors.white.withOpacity(0.1)),
              ),
              child: Text(_filters[i][0].toUpperCase() + _filters[i].substring(1),
                  style: TextStyle(color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    final severity = incident['severity'] as String? ?? 'low';
    final color = _severityColor(severity);
    final type = incident['type'] as String? ?? 'accident';
    final upvotes = incident['upvotes'] as int? ?? 0;
    final id = incident['id'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, spreadRadius: 1)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_typeIcon(type), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(incident['location'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(severity.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(incident['description'] as String? ?? '',
            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.access_time_rounded, color: Colors.white38, size: 12),
          const SizedBox(width: 4),
          Text(_timeAgo(incident['reported_at'] as String?),
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const Spacer(),
          GestureDetector(
            onTap: () => _upvoteIncident(id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.thumb_up_rounded, color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text('$upvotes', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showRouteInfo(incident),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.alt_route_rounded, color: Colors.white54, size: 12),
                SizedBox(width: 4),
                Text('Avoid', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hr ago';
      return '${diff.inDays} days ago';
    } catch (_) { return ts; }
  }
}

class _QuickReportSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  const _QuickReportSheet({required this.onSubmit});
  @override
  State<_QuickReportSheet> createState() => _QuickReportSheetState();
}

class _QuickReportSheetState extends State<_QuickReportSheet> {
  String? _type;
  String _location = '';
  final _ctrl = TextEditingController();

  final _types = [
    {'type': 'accident',     'icon': '🚗', 'label': 'Accident'},
    {'type': 'flood',        'icon': '🌊', 'label': 'Waterlogging'},
    {'type': 'construction', 'icon': '🚧', 'label': 'Construction'},
    {'type': 'signal',       'icon': '🚦', 'label': 'Signal Issue'},
    {'type': 'pothole',      'icon': '🕳️', 'label': 'Pothole'},
    {'type': 'event',        'icon': '🎭', 'label': 'Event'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick Report', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _types.map((t) {
              final selected = _type == t['type'];
              return GestureDetector(
                onTap: () => setState(() => _type = t['type'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFE8581C).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? const Color(0xFFE8581C) : Colors.white.withOpacity(0.1)),
                  ),
                  child: Text('${t['icon']} ${t['label']}',
                      style: TextStyle(color: selected ? const Color(0xFFE8581C) : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Location (e.g. Silk Board Junction)',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true, fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (v) => _location = v,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _type == null || _location.isEmpty ? null : () {
                widget.onSubmit({'type': _type, 'location': _location, 'area': 'Bengaluru', 'severity': 'moderate'});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8581C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
