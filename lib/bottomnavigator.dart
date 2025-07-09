import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard.dart';
// import 'leads.dart';
import 'sidebar.dart'; // Import Sidebar widget
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Set status bar color to red
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.red, // Red status bar color
        statusBarIconBrightness:
            Brightness.light, // Light icons to contrast against red
        statusBarBrightness:
            Brightness.dark, // Dark background for the status bar
      ),
    );

    _pages = [
      const Dashboard(key: ValueKey('dashboard')),
      // const Leads(key: ValueKey('leads')),
    ];
  }

  // Define the _onItemTapped function
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Sidebar(
        onLogout: () {
          setState(() {
            // Refresh dashboard by recreating it with a new key
            _pages[0] = Dashboard(key: UniqueKey());
            _selectedIndex = 0; // Switch to dashboard page
          });
        },
      ), // Added sidebar drawer here
      body: _pages[_selectedIndex], // Removed Stack & Positioned menu icon

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Dashboard",
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                'assets/leads.svg',
                width: 24,
                height: 24,
                color: _selectedIndex == 1 ? Colors.red : Colors.grey,
              ),
              label: "Leads",
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.red,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.questrial(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.questrial(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          onTap: _onItemTapped, // Use the function here
        ),
      ),
    );
  }
}
