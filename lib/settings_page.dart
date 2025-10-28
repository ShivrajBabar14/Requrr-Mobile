import 'package:flutter/material.dart';
import 'account_settings.dart';
import 'notification_preferences.dart';
import 'security_settings.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? token;

  final List<Tab> myTabs = <Tab>[
    const Tab(text: 'Accounts'),
    const Tab(text: 'Notification'),
    const Tab(text: 'Security'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: myTabs.length, vsync: this);
    fetchToken();
  }

  Future<void> fetchToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('accessToken') ?? prefs.getString('token');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => Dashboard(token: token),
              ),
            );
          },
        ),
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        // Removed TabBar from AppBar to have only one AppBar
        // bottom: TabBar(
        //   controller: _tabController,
        //   tabs: myTabs,
        //   labelColor: Colors.black,
        //   unselectedLabelColor: Colors.grey,
        //   indicatorColor: Colors.black,
        //   labelStyle: GoogleFonts.questrial(fontWeight: FontWeight.bold),
        //   unselectedLabelStyle: GoogleFonts.questrial(),
        // ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: MediaQuery.of(context).padding.left,
          // top: MediaQuery.of(context).padding.top,
          right: MediaQuery.of(context).padding.right,
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: myTabs,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              labelStyle: GoogleFonts.questrial(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.questrial(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  AccountSettingsPage(),
                  NotificationPreferencesPage(),
                  SecuritySettingsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
