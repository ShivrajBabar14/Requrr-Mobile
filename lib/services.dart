import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'login.dart';
import 'dashboard.dart';
import 'clients.dart';

class ServicesPage extends StatefulWidget {
  final String? token;
  const ServicesPage({super.key, this.token});

  @override
  _ServicesPageState createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String? aToken;
  List<dynamic> services = [];
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    fetchServices();
  }

  Future<void> _initializeToken() async {
    if (widget.token != null) {
      aToken = widget.token;
    } else {
      final prefs = await SharedPreferences.getInstance();
      aToken = prefs.getString('auth_token');
    }
    fetchServices();
  }

  Future<void> fetchServices() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (aToken == null || aToken!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        aToken = prefs.getString('auth_token');
      }

      if (!isTokenValid(aToken)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
        return;
      }

      final trimmedToken = aToken!.trim();
      final urls = [
        'https://requrr.com/api/Services',
        'https://www.requrr.com/api/Services',
      ];

      http.Response? response;

      for (final url in urls) {
        try {
          print('Trying to fetch from: $url'); // Debug print
          response = await http
              .get(
                Uri.parse(url),
                headers: {
                  'Authorization': 'Bearer $trimmedToken',
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 10));

          print('Response status: ${response.statusCode}'); // Debug print
          if (response.statusCode == 200) {
            break;
          }
        } catch (e) {
          print('Error fetching from $url: $e'); // Debug print
        }
      }

      if (response == null) {
        throw Exception('All API endpoints failed');
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch services. Status: ${response.statusCode}\n'
          'Please check the API endpoint and your internet connection.',
        );
      }

      final responseBody = response.body;
      if (responseBody.isEmpty) {
        throw Exception('Empty response received from server');
      }

      final List<dynamic> servicesList;
      try {
        servicesList = json.decode(responseBody);
        print(
          'Successfully fetched ${servicesList.length} services',
        ); // Debug print
      } catch (e) {
        throw Exception('Failed to parse JSON: ${e.toString()}');
      }

      if (mounted) {
        setState(() {
          services = servicesList;
        });
      }
    } catch (e) {
      print('Error in fetchServices: $e'); // Debug print
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.black),
              child: Text(
                'Menu',
                style: GoogleFonts.questrial(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Dashboard'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Dashboard(token: aToken),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('Clients'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientsPage(token: aToken),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(
          "Services",
          style: GoogleFonts.questrial(color: Colors.black, fontSize: 15),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.grey.withOpacity(0.5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (services.isEmpty)
              Center(
                child: Text(
                  "No services found",
                  style: GoogleFonts.questrial(color: Colors.grey),
                ),
              )
            else
              ...services.map((service) => _serviceCard(service)).toList(),
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
          currentIndex: 1, // Services tab is active
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => Dashboard(token: aToken),
                ),
              );
            } else if (index == 2) {
              Navigator.pushReplacement(
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

  Widget _serviceCard(dynamic service) {
    String formattedDate = '';
    if (service['created_at'] != null) {
      try {
        DateTime createdAt = DateTime.parse(service['created_at']);
        formattedDate = DateFormat('dd MMM yyyy').format(createdAt);
      } catch (e) {
        formattedDate = 'Invalid date';
      }
    }

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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service['name']?.toString() ?? 'No Name',
                    style: GoogleFonts.questrial(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (formattedDate.isNotEmpty)
                  Text(
                    formattedDate,
                    style: GoogleFonts.questrial(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _serviceInfoRow(
              'Description',
              service['description'] ?? 'No description',
            ),
            _serviceInfoRow('Billing Type', service['billing_type'] ?? 'N/A'),
            _serviceInfoRow(
              'Billing Interval',
              '${service['billing_interval']?.toString() ?? 'N/A'} months',
            ),
            _serviceInfoRow(
              'Base Price',
              '₹${service['base_price']?.toString() ?? '0.00'}',
            ),
            _serviceInfoRow(
              'Status',
              service['is_active'] == 1 ? 'Active' : 'Inactive',
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.questrial(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.questrial(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
