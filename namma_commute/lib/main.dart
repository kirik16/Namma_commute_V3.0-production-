import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/live_traffic_screen.dart';
import 'screens/namma_metro_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/report_screen.dart';
import 'screens/about_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const NammaCommuteApp());
}

class NammaCommuteApp extends StatelessWidget {
  const NammaCommuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namma Commute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8581C),
          brightness: Brightness.dark,
          primary: const Color(0xFFE8581C),
          secondary: const Color(0xFF00C9A7),
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  void _navigateTo(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _navigateTo),
      const LiveTrafficScreen(),
      const NammaMetroScreen(),
      const ReportScreen(),
      const SOSScreen(),
      const AboutScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, 'Home', const Color(0xFFE8581C)),
              _navItem(1, Icons.traffic_rounded, 'Traffic', const Color(0xFFE8581C)),
              _navItem(2, Icons.train_rounded, 'Metro', const Color(0xFFE8581C)),
              _navItem(3, Icons.report_problem_rounded, 'Report', const Color(0xFFE8581C)),
              _navItem(4, Icons.emergency_rounded, 'SOS', const Color(0xFFFF4444)),
              _navItem(5, Icons.people_rounded, 'About', const Color(0xFF6C63FF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, Color color) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _navigateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? color : Colors.white30, size: 22),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: isActive ? color : Colors.white30,
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            )),
          ],
        ),
      ),
    );
  }
}
