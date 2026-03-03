import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _refreshTimer;
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';
  Map<String, dynamic> _cityIndex = {};
  List<dynamic> _hotspots = [];
  Map<String, dynamic> _weather = {};
  String _weatherSummary = '';
  int _syncCycles = 0;
  DateTime? _lastUpdated;

  final List<Map<String, dynamic>> _quickActions = [
    {'icon': Icons.directions_car_rounded, 'label': 'Live\nTraffic', 'color': Color(0xFFE8581C), 'tab': 1},
    {'icon': Icons.train_rounded,          'label': 'Namma\nMetro',  'color': Color(0xFF6C63FF), 'tab': 2},
    {'icon': Icons.report_problem_rounded, 'label': 'Report\nIssue', 'color': Color(0xFF00C9A7), 'tab': 3},
    {'icon': Icons.emergency_rounded,      'label': 'SOS\nHelp',     'color': Color(0xFFFF4444), 'tab': 4},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final dashboard = await ApiService.getLiveDashboard();
      if (!mounted) return;
      setState(() {
        _cityIndex = (dashboard['traffic']?['city_index'] as Map<String, dynamic>?) ?? {};
        _hotspots = (dashboard['traffic']?['junctions'] as List<dynamic>?) ?? [];
        _weather = (dashboard['weather']?['current'] as Map<String, dynamic>?) ?? {};
        _weatherSummary = dashboard['weather']?['summary'] as String? ?? '';
        _syncCycles = dashboard['sync']?['cycle_count'] as int? ?? 0;
        _lastUpdated = DateTime.now();
        _loading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Color _severityColor(String? s) {
    switch (s) {
      case 'critical': return const Color(0xFFFF2D55);
      case 'high':     return const Color(0xFFFF9500);
      case 'moderate': return const Color(0xFFFFCC00);
      default:         return const Color(0xFF34C759);
    }
  }

  String _timeAgo() {
    if (_lastUpdated == null) return '';
    final diff = DateTime.now().difference(_lastUpdated!).inSeconds;
    if (diff < 60) return 'Updated ${diff}s ago';
    return 'Updated ${diff ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFFE8581C),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFE8581C))))
            else if (_hasError)
              SliverToBoxAdapter(child: _buildError())
            else ...[
              SliverToBoxAdapter(child: _buildTrafficScore()),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildHotspotsHeader()),
              SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildHotspotCard(_hotspots[i] as Map<String, dynamic>, i),
                childCount: _hotspots.length > 6 ? 6 : _hotspots.length,
              )),
              SliverToBoxAdapter(child: _buildWeatherBanner()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A0A00), Color(0xFF0F0F1A)]),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8581C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8581C).withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Text('● LIVE', style: TextStyle(color: Color(0xFFE8581C), fontSize: 10, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const Spacer(),
                  if (_weather['temp'] != null)
                    Text('🌤️  ${(_weather['temp'] as num).toStringAsFixed(0)}°C',
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                Text('Namma Commute', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                Text(_timeAgo().isNotEmpty ? 'Bengaluru · ${_timeAgo()}' : 'Bengaluru Traffic Intelligence',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const Text('📡', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('Could not connect to server', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_errorMsg, style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () { setState(() { _loading = true; _hasError = false; }); _fetchData(); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8581C)),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficScore() {
    final score = _cityIndex['index'] as int? ?? 50;
    final label = _cityIndex['label'] as String? ?? 'Calculating...';
    final critical = _cityIndex['critical_count'] as int? ?? 0;
    final scoreColor = score > 65 ? const Color(0xFF34C759) : score > 45 ? const Color(0xFFFFCC00) : const Color(0xFFFF2D55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [const Color(0xFFE8581C).withOpacity(0.15), const Color(0xFF16162A)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8581C).withOpacity(0.2)),
        ),
        child: Row(children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (ctx, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
            child: SizedBox(width: 90, height: 90,
              child: CustomPaint(
                painter: _RingPainter(score / 100, scoreColor),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('$score', style: TextStyle(color: scoreColor, fontSize: 26, fontWeight: FontWeight.w900)),
                  const Text('/100', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ])),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('City Traffic Index', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: scoreColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(label.toUpperCase(), style: TextStyle(color: scoreColor, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Text(critical > 0 ? '⚠️ $critical critical incident${critical > 1 ? "s" : ""} active' : '✅ No critical incidents',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text('AI sync #$_syncCycles · auto-refreshes every 30s', style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: _quickActions.map((action) {
          final color = action['color'] as Color;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => widget.onNavigate?.call(action['tab'] as int),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Column(children: [
                    Icon(action['icon'] as IconData, color: color, size: 24),
                    const SizedBox(height: 6),
                    Text(action['label'] as String,
                        style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHotspotsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(children: [
        const Text('🔥 AI Traffic Hotspots', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const Spacer(),
        GestureDetector(
          onTap: () => widget.onNavigate?.call(1),
          child: const Text('See All →', style: TextStyle(color: Color(0xFFE8581C), fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildHotspotCard(Map<String, dynamic> hotspot, int index) {
    final severity = hotspot['severity'] as String? ?? 'low';
    final color = _severityColor(severity);
    final delay = hotspot['delay_min'] as int? ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GestureDetector(
        onTap: () => widget.onNavigate?.call(1),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hotspot['junction'] as String? ?? hotspot['name'] as String? ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              Text(hotspot['message'] as String? ?? severity.toUpperCase(),
                  style: const TextStyle(color: Colors.white54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$delay min', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('delay', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildWeatherBanner() {
    final main = _weather['main'] as String? ?? 'Clear';
    final temp = (_weather['temp'] as num?)?.toStringAsFixed(0) ?? '28';
    final desc = _weather['description'] as String? ?? 'clear sky';
    final rain = (_weather['rain_1h'] as num? ?? 0) > 0;
    final icon = main.toLowerCase().contains('rain') ? '🌧️' : main.toLowerCase().contains('cloud') ? '⛅' : '☀️';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF6C63FF).withOpacity(0.15), const Color(0xFF00C9A7).withOpacity(0.08)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bengaluru · $temp°C · ${desc[0].toUpperCase()}${desc.substring(1)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 3),
            Text(rain ? '🚦 Rain — expect +15-20 min delays on ORR' : 'Weather not impacting traffic currently',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withOpacity(0.07)..strokeWidth = 8..style = PaintingStyle.stroke);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false,
        Paint()..color = color..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
