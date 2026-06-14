import 'package:flutter/material.dart';
import 'package:t_axis/mobile/screens/mobile_dashboard_screen.dart';
import 'package:t_axis/mobile/screens/rides_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static final List<Widget> _pages = [
    const MobileDashboardScreen(),
    const RidesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Rides'),
        ],
      ),
    );
  }
}
