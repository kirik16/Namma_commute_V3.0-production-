import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class NammaMetroScreen extends StatefulWidget {
  const NammaMetroScreen({super.key});
  @override
  State<NammaMetroScreen> createState() => _NammaMetroScreenState();
}

class _NammaMetroScreenState extends State<NammaMetroScreen> {
  int _selectedLine = 0;
  bool _loading = true;
  List<dynamic> _lines = [];
  List<dynamic> _stations = [];
  List<dynamic> _schedule = [];
  List<dynamic> _aiStatus = [];
  Timer? _refreshTimer;

  // Fare calculator state
  String? _fareFrom;
  String? _fareTo;
  Map<String, dynamic>? _fareResult;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchSchedule());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([
        ApiService.getMetroLines(),
        ApiService.getMetroAiStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _lines = results[0] as List<dynamic>;
        _aiStatus = results[1] as List<dynamic>;
        _loading = false;
      });
      if (_lines.isNotEmpty) _fetchStationsAndSchedule();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchSchedule() async {
    if (_lines.isEmpty) return;
    try {
      final lineId = _lines[_selectedLine]['id'] as int;
      final results = await Future.wait([
        ApiService.getMetroAiStatus(),
        ApiService.getMetroSchedule(lineId),
      ]);
      if (!mounted) return;
      setState(() {
        _aiStatus = results[0] as List<dynamic>;
        _schedule = results[1] as List<dynamic>;
      });
    } catch (_) {}
  }

  Future<void> _fetchStationsAndSchedule() async {
    if (_lines.isEmpty) return;
    try {
      final lineId = _lines[_selectedLine]['id'] as int;
      final results = await Future.wait([
        ApiService.getMetroStations(lineId),
        ApiService.getMetroSchedule(lineId),
      ]);
      if (!mounted) return;
      setState(() {
        _stations = results[0] as List<dynamic>;
        _schedule = results[1] as List<dynamic>;
      });
    } catch (_) {}
  }

  Future<void> _calcFare() async {
    if (_fareFrom == null || _fareTo == null || _lines.isEmpty) return;
    try {
      final lineId = _lines[_selectedLine]['id'] as int;
      final result = await ApiService.getMetroFare(lineId, _fareFrom!, _fareTo!);
      if (!mounted) return;
      setState(() => _fareResult = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Map<String, dynamic>? get _currentAiLine {
    if (_aiStatus.isEmpty || _lines.isEmpty) return null;
    final lineId = _lines[_selectedLine]['id'];
    for (final l in _aiStatus) {
      if (l['line_id'] == lineId) return l as Map<String, dynamic>;
    }
    return _aiStatus.isNotEmpty ? _aiStatus[0] as Map<String, dynamic> : null;
  }

  Color _lineColor() {
    if (_lines.isEmpty) return const Color(0xFF7B2D8B);
    final colorStr = _lines[_selectedLine]['color'] as String? ?? '#7B2D8B';
    return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B2D8B)))
          : Column(children: [
              _buildHeader(),
              _buildLineSelector(),
              _buildAiStatus(),
              Expanded(child: DefaultTabController(
                length: 3,
                child: Column(children: [
                  _buildTabBar(),
                  Expanded(child: TabBarView(children: [
                    _buildScheduleTab(),
                    _buildStationsTab(),
                    _buildFareTab(),
                  ])),
                ]),
              )),
            ]),
    );
  }

  Widget _buildHeader() {
    final lineColor = _lineColor();
    final lineName = _lines.isNotEmpty ? _lines[_selectedLine]['name'] as String? ?? 'Metro' : 'Namma Metro';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [lineColor.withOpacity(0.3), const Color(0xFF0F0F1A)]),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Namma Metro', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(lineName, style: TextStyle(color: lineColor, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_lines.isNotEmpty) Row(children: [
            _statBox('${_lines[_selectedLine]['total_stations'] ?? '?'}', 'Stations', lineColor),
            const SizedBox(width: 10),
            _statBox('${(_lines[_selectedLine]['distance_km'] as num?)?.toStringAsFixed(0) ?? '?'}km', 'Distance', lineColor),
            const SizedBox(width: 10),
            _statBox('${_lines[_selectedLine]['frequency_min'] ?? '?'} min', 'Frequency', lineColor),
          ]),
        ]),
      )),
    );
  }

  Widget _statBox(String val, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(val, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ]),
    ));
  }

  Widget _buildLineSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(_lines.length, (i) {
          final l = _lines[i];
          final isSelected = _selectedLine == i;
          final colorStr = l['color'] as String? ?? '#7B2D8B';
          final c = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
          return Expanded(child: GestureDetector(
            onTap: () {
              setState(() { _selectedLine = i; _stations = []; _schedule = []; _fareResult = null; });
              _fetchStationsAndSchedule();
            },
            child: Container(
              margin: EdgeInsets.only(right: i < _lines.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? c.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? c : Colors.white.withOpacity(0.08), width: isSelected ? 1.5 : 1),
              ),
              child: Text(l['name'] as String? ?? 'Line ${i+1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isSelected ? c : Colors.white38, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ));
        }),
      ),
    );
  }

  Widget _buildAiStatus() {
    final ai = _currentAiLine;
    if (ai == null) return const SizedBox.shrink();
    final status = ai['status'] as String? ?? 'on_time';
    final delay = ai['delay_min'] as int? ?? 0;
    final reasons = (ai['reasons'] as List<dynamic>?) ?? [];
    final statusColor = status == 'on_time' ? const Color(0xFF34C759) : status == 'slight_delay' ? const Color(0xFFFFCC00) : const Color(0xFFFF2D55);
    final lineColor = _lineColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(status == 'on_time' ? Icons.check_circle_rounded : Icons.warning_rounded, color: statusColor, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(status == 'on_time' ? 'Services Running Normally' : 'Delay: $delay min',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13)),
          if (reasons.isNotEmpty)
            Text(reasons[0] as String, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: lineColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('AI Live', style: TextStyle(color: lineColor, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    final lineColor = _lineColor();
    return TabBar(
      indicatorColor: lineColor,
      labelColor: lineColor,
      unselectedLabelColor: Colors.white38,
      tabs: const [Tab(text: 'Next Trains'), Tab(text: 'Stations'), Tab(text: 'Fare')],
    );
  }

  Widget _buildScheduleTab() {
    if (_schedule.isEmpty) return const Center(child: Text('No schedule data', style: TextStyle(color: Colors.white38)));
    final lineColor = _lineColor();
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _schedule.length,
      itemBuilder: (ctx, i) {
        final s = _schedule[i] as Map<String, dynamic>;
        final status = s['status'] as String? ?? 'on_time';
        final statusColor = status == 'on_time' ? const Color(0xFF34C759) : const Color(0xFFFFCC00);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF16162A), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07))),
          child: Row(children: [
            Icon(Icons.train_rounded, color: lineColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['from_station']} → ${s['to_station']}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Departs in ${s['departure']}',
                  style: TextStyle(color: lineColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(status == 'on_time' ? 'On Time' : 'Delayed',
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildStationsTab() {
    if (_stations.isEmpty) return const Center(child: CircularProgressIndicator(color: Color(0xFF7B2D8B)));
    final lineColor = _lineColor();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _stations.length,
      itemBuilder: (ctx, i) {
        final s = _stations[i] as Map<String, dynamic>;
        final isHub = s['is_hub'] == true || s['is_hub'] == 1;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 40, child: Column(children: [
            if (i > 0) Container(width: 2, height: 12, color: lineColor.withOpacity(0.5)),
            Container(width: isHub ? 14 : 10, height: isHub ? 14 : 10,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: isHub ? lineColor : lineColor.withOpacity(0.4),
                    border: isHub ? Border.all(color: Colors.white, width: 2) : null)),
            if (i < _stations.length - 1) Container(width: 2, height: 28, color: lineColor.withOpacity(0.5)),
          ])),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Row(children: [
              Expanded(child: Text(s['name'] as String? ?? '',
                  style: TextStyle(color: isHub ? Colors.white : Colors.white70,
                      fontSize: isHub ? 13 : 12, fontWeight: isHub ? FontWeight.w700 : FontWeight.w400))),
              if (isHub) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: lineColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('HUB', style: TextStyle(color: lineColor, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ]),
          )),
        ]);
      },
    );
  }

  Widget _buildFareTab() {
    final lineColor = _lineColor();
    final stationNames = _stations.map((s) => s['name'] as String).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Calculate Fare', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        _dropdownField('From Station', _fareFrom, stationNames, (v) => setState(() => _fareFrom = v)),
        const SizedBox(height: 12),
        _dropdownField('To Station', _fareTo, stationNames, (v) => setState(() => _fareTo = v)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: _fareFrom != null && _fareTo != null && _fareFrom != _fareTo ? _calcFare : null,
            style: ElevatedButton.styleFrom(backgroundColor: lineColor, padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Calculate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
        if (_fareResult != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: lineColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: lineColor.withOpacity(0.3))),
            child: Column(children: [
              Text('₹${_fareResult!['fare_inr']}',
                  style: TextStyle(color: lineColor, fontSize: 48, fontWeight: FontWeight.w900)),
              Text('${_fareResult!['stops']} stops · ${_fareFrom} → ${_fareTo}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_fareResult!['note'] as String? ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _dropdownField(String label, String? value, List<String> options, void Function(String?) onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF16162A),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            hint: Text('Select station', style: TextStyle(color: Colors.white30)),
            items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: onChange,
          ),
        ),
      ),
    ]);
  }
}
