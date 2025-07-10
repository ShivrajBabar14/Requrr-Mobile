import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';
import 'dashboard.dart';
import 'clients.dart';
import 'sidebar.dart';

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
    setState(() => isLoading = true);

    try {
      if (aToken == null || aToken!.isEmpty) {
        aToken = (await SharedPreferences.getInstance()).getString(
          'auth_token',
        );
      }

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
        'https://requrr.com/api/Services',
        'https://www.requrr.com/api/Services',
      ];

      // 1. Use Future.wait for parallel requests
      final responses = await Future.wait(
        urls.map(
          (url) => http
              .get(
                Uri.parse(url),
                headers: {
                  'Authorization': 'Bearer $trimmedToken',
                  'Accept': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 5)),
        ), // Reduced timeout
        eagerError: true, // Fail fast if any request fails
      );

      // 2. Find first successful response
      final response = responses.firstWhere(
        (r) => r.statusCode == 200,
        orElse: () => throw Exception('All endpoints failed'),
      );

      // 3. Optimized JSON parsing
      final servicesList = (json.decode(response.body) as List).cast<dynamic>();

      if (mounted) {
        setState(() => services = servicesList);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll(RegExp(r'^Exception: '), '')),
            duration: const Duration(seconds: 3), // Shorter error display
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Sidebar(
        // Use Sidebar directly as the drawer
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
          "Services",
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
                color: Colors.black, // Simplified version for Flutter 2.0+
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (services.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.8,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/noservices.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...services
                        .map((service) => _serviceCard(service))
                        .toList(),
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

  // Widget _serviceCard(dynamic service) {
  //   final bool isActive = service['is_active'] == 1;
  //   final Color statusColor = isActive ? Colors.green : Colors.grey;

  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 8),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(8),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.1),
  //           blurRadius: 6,
  //           offset: const Offset(0, 3),
  //         ),
  //       ],
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // Name, Status, and Edit icon row
  //           SizedBox(
  //             height: 20,
  //             child: Row(
  //               children: [
  //                 Expanded(
  //                   child: Align(
  //                     alignment: Alignment.centerLeft,
  //                     child: Text(
  //                       service['name']?.toString() ?? 'No Name',
  //                       style: GoogleFonts.questrial(
  //                         fontSize: 16,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.black,
  //                       ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                     ),
  //                   ),
  //                 ),
  //                 // Status badge
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 8,
  //                     vertical: 2,
  //                   ),
  //                   decoration: BoxDecoration(
  //                     color: statusColor.withOpacity(0.2),
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                   child: Text(
  //                     isActive ? 'Active' : 'Inactive',
  //                     style: GoogleFonts.questrial(
  //                       fontSize: 12,
  //                       color: statusColor,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 10),
  //                 // Edit icon
  //                 GestureDetector(
  //                   onTap: () {
  //                     // Add edit functionality here
  //                   },
  //                   child: const Icon(Icons.edit, size: 15, color: Colors.grey),
  //                 ),
  //                 const SizedBox(width: 10),
  //                 // Delete icon
  //                 GestureDetector(
  //                   onTap: () {
  //                     // Add delete functionality here
  //                   },
  //                   child: const Icon(
  //                     Icons.delete,
  //                     size: 15,
  //                     color: Colors.redAccent,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),

  //           // Description
  //           if (service['description'] != null &&
  //               service['description'].toString().isNotEmpty)
  //             Padding(
  //               padding: const EdgeInsets.only(top: 2, bottom: 4, right: 100),
  //               child: Text(
  //                 service['description'].toString(),
  //                 style: GoogleFonts.questrial(
  //                   fontSize: 14,
  //                   color: Colors.grey[600],
  //                 ),
  //               ),
  //             ),

  //           // Details row
  //           Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               // Left column (unchanged)
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     _buildInfoRow(
  //                       'Service Type',
  //                       service['billing_type'] ?? 'N/A',
  //                     ),
  //                     const SizedBox(height: 4),
  //                     _buildInfoRow(
  //                       'Billing Interval',
  //                       '${service['billing_interval']?.toString() ?? 'N/A'} months',
  //                     ),
  //                   ],
  //                 ),
  //               ),

  //               // Right column with highlighted price
  //               Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   RichText(
  //                     text: TextSpan(
  //                       style: GoogleFonts.questrial(
  //                         fontSize: 14,
  //                         color: Colors.black,
  //                       ),
  //                       children: [
  //                         TextSpan(
  //                           // text: 'Base Price: ',
  //                           style: TextStyle(
  //                             color: Colors.grey[600],
  //                             fontSize: 12,
  //                           ),
  //                         ),
  //                         TextSpan(
  //                           text:
  //                               '₹${service['base_price']?.toString() ?? '0.00'}',
  //                           style: TextStyle(
  //                             fontWeight: FontWeight.bold,
  //                             fontSize: 15,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _serviceCard(dynamic service) {
    final bool isActive = service['is_active'] == 1;
    final Color statusColor = isActive ? Colors.green : Colors.grey;

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
            // Top row with name and status/action icons
            Row(
              children: [
                Expanded(
                  child: Text(
                    service['name']?.toString() ?? 'No Name',
                    style: GoogleFonts.questrial(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.questrial(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Edit icon
                GestureDetector(
                  onTap: () {
                    // Add edit functionality here
                  },
                  child: const Icon(Icons.edit, size: 15, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                // Delete icon
                GestureDetector(
                  onTap: () {
                    // Add delete functionality here
                  },
                  child: const Icon(
                    Icons.delete,
                    size: 15,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),

            // Description and Price row
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        service['description'] != null &&
                            service['description'].toString().isNotEmpty
                        ? Text(
                            service['description'].toString(),
                            style: GoogleFonts.questrial(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          )
                        : const SizedBox(),
                  ),
                  Text(
                    '₹${service['base_price']?.toString() ?? '0.00'}',
                    style: GoogleFonts.questrial(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Service details row (service type and billing interval in one row)
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    'Service Type',
                    service['billing_type'] ?? 'N/A',
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildInfoRow(
                      'Billing Interval',
                      '${service['billing_interval']?.toString() ?? 'N/A'} months',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.questrial(fontSize: 14, color: Colors.black),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
