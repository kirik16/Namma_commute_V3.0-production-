import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  final List<Map<String, dynamic>> _team = [
    {
      'name': 'Subhradip',
      'role': 'System Design',
      'icon': '🏗️',
      'initial': 'S',
      'desc':
          'Architected the entire system — designed scalable microservices, API contracts, data flow, and module structure powering Namma Commute.',
      'tags': ['System Architecture', 'API Design', 'Scalability'],
      'color': Color(0xFFE8581C),
      'gradient': [Color(0xFFE8581C), Color(0xFFFF8C42)],
    },
    {
      'name': 'Shivakumar',
      'role': 'Backend & Database',
      'icon': '🗄️',
      'initial': 'S',
      'desc':
          'Built robust backend services and optimised databases handling real-time traffic feeds, incident reports, and metro schedule sync across Bengaluru.',
      'tags': ['Backend Dev', 'Database', 'Real-time Sync'],
      'color': Color(0xFF6C63FF),
      'gradient': [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
    },
    {
      'name': 'Devansh',
      'role': 'Agentic AI',
      'icon': '🤖',
      'initial': 'D',
      'desc':
          'Engineered agentic AI systems for predictive congestion analysis, smart re-routing, and citizen report classification using real-time Bengaluru traffic patterns.',
      'tags': ['Agentic AI', 'ML Models', 'NLP'],
      'color': Color(0xFF00C9A7),
      'gradient': [Color(0xFF00C9A7), Color(0xFF00E5BF)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildMission()),
          SliverToBoxAdapter(child: _buildStats()),
          SliverToBoxAdapter(child: _buildTeamHeader()),
          ..._team.map((m) => SliverToBoxAdapter(child: _buildMemberCard(m))),
          SliverToBoxAdapter(child: _buildFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF150820), Color(0xFF0F0F1A)],
        ),
      ),
      child: Stack(
        children: [
          // Glow blobs
          Positioned(
            top: -20, left: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFE8581C).withOpacity(0.2),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            top: -10, right: -30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF6C63FF).withOpacity(0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Column(
            children: [
              // Floating logo
              AnimatedBuilder(
                animation: _floatAnimation,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                ),
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8581C), Color(0xFFFF8C42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8581C).withOpacity(0.45),
                        blurRadius: 30, spreadRadius: 2, offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🚗', style: TextStyle(fontSize: 36)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Namma Commute',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 26, fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Bengaluru's Unified Traffic Intelligence",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  'v1.0.0 · Built for Bengaluru 🇮🇳',
                  style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMission() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎯  OUR MISSION',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2,
                )),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, height: 1.75),
                children: [
                  const TextSpan(text: 'Bengaluru loses '),
                  TextSpan(
                    text: '\$6 billion',
                    style: const TextStyle(color: Color(0xFFE8581C), fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' annually to traffic congestion. The average commuter wastes '),
                  TextSpan(
                    text: '243 hours/year',
                    style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text: ' stuck at signals. Namma Commute puts real-time intelligence, citizen reporting, and emergency tools in every Bengalurean\'s pocket.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final stats = [
      {'val': '12M+', 'lbl': 'Daily Commuters', 'color': Color(0xFFE8581C)},
      {'val': '5', 'lbl': 'App Modules', 'color': Color(0xFF6C63FF)},
      {'val': 'Live', 'lbl': 'Traffic Data', 'color': Color(0xFF00C9A7)},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: stats.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(s['val'] as String,
                            style: TextStyle(
                              color: s['color'] as Color,
                              fontSize: 20, fontWeight: FontWeight.w900,
                            )),
                        const SizedBox(height: 3),
                        Text(s['lbl'] as String,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 9, fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  if (i < stats.length - 1)
                    Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTeamHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚡  THE TEAM',
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5,
              )),
          const SizedBox(height: 4),
          Text('Built with ❤️ in Bengaluru',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m) {
    final color = m['color'] as Color;
    final gradient = m['gradient'] as List<Color>;
    final tags = m['tags'] as List<String>;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16162A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Top section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.14), color.withOpacity(0.03)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 12, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(m['initial'] as String,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
                          )),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'] as String,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 3),
                        Text((m['role'] as String).toUpperCase(),
                            style: TextStyle(
                              color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7,
                            )),
                      ],
                    ),
                  ),
                  Text(m['icon'] as String, style: const TextStyle(fontSize: 26)),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['desc'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12, height: 1.7,
                      )),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.w700,
                          )),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        ),
        child: Column(
          children: [
            const Text('🚗', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text('Namma Commute',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 4),
            Text('Made for Bengalureans, by Bengalureans',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
            const SizedBox(height: 14),
            Text('© 2025 Namma Commute Team · All rights reserved',
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
