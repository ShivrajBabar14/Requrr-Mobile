import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sidebar.dart';
import 'login.dart';
import 'services.dart';
import 'dashboard.dart';

class ClientsPage extends StatefulWidget {
  final String? token;
  const ClientsPage({super.key, this.token});

  @override
  _ClientsPageState createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String? aToken;
  List<dynamic> clients = [];
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<int, bool> expandedClients = {}; // Track which clients are expanded

  bool isTokenValid(String? token) {
    if (token == null || token.isEmpty) return false;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final jsonMap = json.decode(decoded);

      if (jsonMap['exp'] == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        jsonMap['exp'] * 1000,
      );
      return expiryDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeToken();
    fetchClients();
  }

  Future<void> _initializeToken() async {
    if (widget.token != null) {
      aToken = widget.token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      aToken = prefs.getString('auth_token');
    }
    print('Initialized token: ${aToken != null ? "exists" : "null"}');
  }

  Future<void> fetchClients() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      aToken ??=
          widget.token ??
          (await SharedPreferences.getInstance()).getString('auth_token');

      if (!isTokenValid(aToken)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
        return;
      }

      final trimmedToken = aToken!.trim();
      final urls = [
        'https://requrr.com/api/clients',
        'https://www.requrr.com/api/clients',
      ];

      final response = await _fetchFirstSuccessful(urls, trimmedToken);
      final clientsList = (json.decode(response.body) as List).cast<dynamic>();

      if (mounted) {
        setState(() {
          clients = clientsList;
          // Initialize all clients as not expanded
          expandedClients = {for (var i = 0; i < clientsList.length; i++) i: false};
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<http.Response> _fetchFirstSuccessful(
    List<String> urls,
    String token,
  ) async {
    final futures = urls.map(
      (url) => http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5)),
    );

    for (final future in futures) {
      try {
        final response = await future;
        if (response.statusCode == 200) return response;
      } catch (_) {}
    }
    throw Exception('All endpoints failed');
  }

  void _toggleExpand(int index) {
    setState(() {
      expandedClients[index] = !(expandedClients[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Sidebar(
        token: aToken,
        onYearSelected: (selectedYear) {},
        onMonthSelected: () {},
        onLogout: () {
          setState(() {
            aToken = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have been logged out')),
          );
        },
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(
          "Clients",
          style: GoogleFonts.questrial(color: Colors.black, fontSize: 15),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.5),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.black,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (clients.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/noclient.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...clients.asMap().entries.map((entry) {
                      final index = entry.key;
                      final client = entry.value;
                      return _clientAccordion(index, client);
                    }).toList(),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: 2, // Clients tab is active
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.questrial(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.questrial(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          onTap: (index) {
            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => Dashboard(token: aToken),
                ),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServicesPage(token: aToken),
                ),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientsPage(token: aToken),
                ),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.miscellaneous_services_outlined),
              label: 'Services',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          ],
        ),
      ),
    );
  }

  Widget _clientAccordion(int index, dynamic client) {
    final isExpanded = expandedClients[index] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row with client name and expand icon
          ListTile(
            title: Text(
              client['name']?.toString() ?? 'No Name',
              style: GoogleFonts.questrial(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.black,
                  ),
                  onPressed: () => _toggleExpand(index),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {}, // Edit functionality
                  child: const Icon(Icons.edit, size: 18, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {}, // Delete functionality
                  child: const Icon(
                    Icons.delete,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            onTap: () => _toggleExpand(index),
          ),
          
          // Expanded content
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  _clientInfoRow(
                    Icons.business,
                    client['company_name'] ?? 'No Company',
                  ),
                  _clientInfoRow(Icons.email, client['email'] ?? 'No Email'),
                  _clientInfoRow(Icons.phone, client['phone'] ?? 'No Phone'),
                  if (client['address'] != null && client['address'].isNotEmpty)
                    _clientInfoRow(Icons.location_on, client['address']),
                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _clientInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.questrial(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}