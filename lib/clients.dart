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

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _companyNameController.dispose();
    _clientNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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
          expandedClients = {
            for (var i = 0; i < clientsList.length; i++) i: false,
          };
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

  Future<void> _saveClientChanges(dynamic clientId) async {
    bool isSaving = true; // Define isSaving locally if not a class variable

    try {
      if (!mounted) return;

      setState(() => isLoading = true);

      final String clientIdStr = clientId.toString();
      Uri url = Uri.parse('https://requrr.com/api/clients/$clientIdStr');

      // Helper function for making the PUT request
      Future<http.Response> makePutRequest(Uri url) async {
        return await http
            .put(
              url,
              headers: {
                'Authorization': 'Bearer $aToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'company_name': _companyNameController.text,
                'name': _clientNameController.text,
                'email': _emailController.text,
                'phone': _phoneController.text,
                'address': _addressController.text,
                'notes': _noteController.text,
              }),
            )
            .timeout(const Duration(seconds: 30));
      }

      // First attempt
      http.Response response = await makePutRequest(url);

      // Handle redirect (status code 307)
      if (response.statusCode == 307) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          url = Uri.parse(redirectUrl);
          response = await makePutRequest(url);
        }
      }

      if (!mounted) return;

      // Debug logging
      debugPrint('Final response status: ${response.statusCode}');
      debugPrint('Final response body: ${response.body}');

      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      // Parse response
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Client updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          await fetchClients();
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        final errorMessage = responseData is Map<String, dynamic>
            ? responseData['message']?.toString() ??
                  'Failed to update client (Status ${response.statusCode})'
            : 'Failed to update client (Status ${response.statusCode})';
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid server response format: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        isSaving = false;
      }
    }
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
          ? Center(child: CircularProgressIndicator(color: Colors.black))
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
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black,
                  ),
                  onPressed: () => _toggleExpand(index),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showEditClientDialog(client),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
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

  void _showEditClientDialog(dynamic client) {
    // Set initial values from the client data
    _companyNameController.text = client['company_name'] ?? '';
    _clientNameController.text = client['name'] ?? '';
    _emailController.text = client['email'] ?? '';
    _phoneController.text = client['phone'] ?? '';
    _addressController.text = client['address'] ?? '';
    _noteController.text = client['notes'] ?? client['note'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            // Add this for better control
            horizontal: 20.0, // Adjust as needed
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width:
                MediaQuery.of(context).size.width * 0.9, // 90% of screen width
            constraints: BoxConstraints(
              maxWidth: 650, // Maximum width for larger screens
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Client',
                    style: GoogleFonts.questrial(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildEditField('Company Name', _companyNameController),
                  _buildEditField('Client Name', _clientNameController),
                  _buildEditField('Email', _emailController, isEmail: true),
                  _buildEditField('Phone', _phoneController, isPhone: true),
                  _buildEditField('Address', _addressController, maxLines: 3),
                  _buildEditField('Note', _noteController, maxLines: 3),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.questrial(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          _saveClientChanges(client['id']);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.questrial(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    bool isEmail = false,
    bool isPhone = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.questrial(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isEmail
                ? TextInputType.emailAddress
                : isPhone
                ? TextInputType.phone
                : TextInputType.text,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black),
              ),
            ),
            style: GoogleFonts.questrial(),
          ),
        ],
      ),
    );
  }
}
