import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';
import 'dashboard.dart';
import 'clients.dart';
import 'sidebar.dart';
import 'dart:io';
import 'dart:async';

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
        ),
        eagerError: true,
      );

      final response = responses.firstWhere(
        (r) => r.statusCode == 200,
        orElse: () => throw Exception('All endpoints failed'),
      );

      final servicesList = (json.decode(response.body) as List).cast<dynamic>();

      if (mounted) {
        setState(() => services = servicesList);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll(RegExp(r'^Exception: '), '')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<bool> addService({
    required String name,
    required String description,
    required String billingType,
    required int billingInterval,
    required double basePrice,
  }) async {
    try {
      // Validate token
      if (aToken == null || aToken!.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      // Validate input data
      if (name.isEmpty) throw Exception('Service name cannot be empty');
      if (basePrice < 0) throw Exception('Base price cannot be negative');
      if (billingInterval <= 0 && billingType == 'recurring') {
        throw Exception(
          'Billing interval must be positive for recurring services',
        );
      }

      final url = Uri.parse('https://requrr.com/api/Services');
      final trimmedToken = aToken!.trim();

      final headers = {
        'Authorization': 'Bearer $trimmedToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final body = json.encode({
        'name': name,
        'description': description,
        'billing_type': billingType,
        'billing_interval': billingInterval.toString(),
        'base_price': basePrice,
      });

      debugPrint('API Request: $url');
      debugPrint('Headers: $headers');
      debugPrint('Body: $body');

      // Create a client that can follow redirects
      final client = http.Client();
      final response = await client
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('API Response: ${response.statusCode} - ${response.body}');

      // Handle redirect response
      if (response.statusCode == 307) {
        final redirectUrl =
            response.headers['location'] ??
            json.decode(response.body)['redirect'] ??
            'https://www.requrr.com/api/Services';

        debugPrint('Following redirect to: $redirectUrl');
        final redirectResponse = await client
            .post(Uri.parse(redirectUrl), headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        debugPrint(
          'Redirect Response: ${redirectResponse.statusCode} - ${redirectResponse.body}',
        );

        if (redirectResponse.statusCode == 200) {
          client.close();
          return true;
        } else {
          client.close();
          throw Exception(
            'Failed after redirect: ${redirectResponse.statusCode}',
          );
        }
      } else if (response.statusCode == 200) {
        client.close();
        return true;
      } else if (response.statusCode == 401) {
        client.close();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        client.close();
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ??
              errorData['error'] ??
              'Failed to add service (${response.statusCode})',
        );
      } else if (response.statusCode >= 500) {
        client.close();
        throw Exception('Server error. Please try again later.');
      } else {
        client.close();
        throw Exception('Unexpected error occurred (${response.statusCode})');
      }
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('HTTP request failed: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: ${e.message}');
    } catch (e) {
      throw Exception('Failed to add service: ${e.toString()}');
    }
  }

  Future<bool> updateService({
    required int serviceId,
    required String name,
    required String description,
    required String billingType,
    required int billingInterval,
    required double basePrice,
  }) async {
    try {
      // Validate token
      if (aToken == null || aToken!.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      // Validate input data
      if (name.isEmpty) throw Exception('Service name cannot be empty');
      if (basePrice < 0) throw Exception('Base price cannot be negative');
      if (billingInterval <= 0 && billingType == 'recurring') {
        throw Exception(
          'Billing interval must be positive for recurring services',
        );
      }

      final url = Uri.parse('https://requrr.com/api/Services/$serviceId');
      final trimmedToken = aToken!.trim();

      final headers = {
        'Authorization': 'Bearer $trimmedToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final body = json.encode({
        'name': name,
        'description': description,
        'billing_type': billingType,
        'billing_interval': billingInterval.toString(),
        'base_price': basePrice,
      });

      debugPrint('API Request: $url');
      debugPrint('Headers: $headers');
      debugPrint('Body: $body');

      // Create a client that can follow redirects
      final client = http.Client();
      final response = await client
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('API Response: ${response.statusCode} - ${response.body}');

      // Handle redirect response
      if (response.statusCode == 307) {
        final redirectUrl =
            response.headers['location'] ??
            json.decode(response.body)['redirect'] ??
            'https://www.requrr.com/api/Services/$serviceId';

        debugPrint('Following redirect to: $redirectUrl');
        final redirectResponse = await client
            .put(Uri.parse(redirectUrl), headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        debugPrint(
          'Redirect Response: ${redirectResponse.statusCode} - ${redirectResponse.body}',
        );

        if (redirectResponse.statusCode == 200) {
          client.close();
          return true;
        } else {
          client.close();
          throw Exception(
            'Failed after redirect: ${redirectResponse.statusCode}',
          );
        }
      } else if (response.statusCode == 200) {
        client.close();
        return true;
      } else if (response.statusCode == 401) {
        client.close();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        client.close();
        throw Exception('Service not found');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        client.close();
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ??
              errorData['error'] ??
              'Failed to update service (${response.statusCode})',
        );
      } else if (response.statusCode >= 500) {
        client.close();
        throw Exception('Server error. Please try again later.');
      } else {
        client.close();
        throw Exception('Unexpected error occurred (${response.statusCode})');
      }
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Network connection failed: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('HTTP request failed: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update service: ${e.toString()}');
    }
  }

  Future<void> _deleteService(int serviceId) async {
    try {
      // Validate token
      if (aToken == null || aToken!.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      );

      final url = Uri.parse('https://requrr.com/api/Services/$serviceId');
      final trimmedToken = aToken!.trim();

      final headers = {
        'Authorization': 'Bearer $trimmedToken',
        'Accept': 'application/json',
      };

      debugPrint('DELETE API Request: $url');
      debugPrint('Headers: $headers');

      // Create a client that can follow redirects
      final client = http.Client();
      final response = await client
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'DELETE API Response: ${response.statusCode} - ${response.body}',
      );

      // Handle redirect response
      if (response.statusCode == 307) {
        final redirectUrl =
            response.headers['location'] ??
            json.decode(response.body)['redirect'] ??
            'https://www.requrr.com/api/Services/$serviceId';

        debugPrint('Following redirect to: $redirectUrl');
        final redirectResponse = await client
            .delete(Uri.parse(redirectUrl), headers: headers)
            .timeout(const Duration(seconds: 15));

        debugPrint(
          'Redirect Response: ${redirectResponse.statusCode} - ${redirectResponse.body}',
        );

        if (redirectResponse.statusCode == 200) {
          client.close();
          if (mounted) Navigator.of(context).pop();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Service deleted successfully'),
                duration: const Duration(seconds: 2),
              ),
            );
            fetchServices();
          }
          return;
        } else {
          client.close();
          throw Exception(
            'Failed after redirect: ${redirectResponse.statusCode}',
          );
        }
      }

      client.close();

      // Close loading indicator
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Service deleted successfully'),
              duration: const Duration(seconds: 2),
            ),
          );
          fetchServices(); // Refresh the list
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Service not found');
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ??
              errorData['error'] ??
              'Failed to delete service (${response.statusCode})',
        );
      } else if (response.statusCode >= 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception('Unexpected error occurred (${response.statusCode})');
      }
    } on TimeoutException catch (e) {
      if (mounted) Navigator.of(context).pop();
      throw Exception('Request timed out: ${e.message}');
    } on SocketException catch (e) {
      if (mounted) Navigator.of(context).pop();
      throw Exception('Network connection failed: ${e.message}');
    } on http.ClientException catch (e) {
      if (mounted) Navigator.of(context).pop();
      throw Exception('HTTP request failed: ${e.message}');
    } on FormatException catch (e) {
      if (mounted) Navigator.of(context).pop();
      throw Exception('Invalid response format: ${e.message}');
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete service: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showAddServiceDialog() async {
    final _formKey = GlobalKey<FormState>();

    // Local variables to hold form data (initially empty for add)
    String name = '';
    String description = '';
    String billingType = 'one-time';
    int billingInterval = 1;
    double basePrice = 0.0;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Service',
                        style: GoogleFonts.questrial(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name Field
                      TextFormField(
                        initialValue: name,
                        decoration: InputDecoration(
                          labelText: 'Service Name',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter service name';
                          }
                          return null;
                        },
                        onChanged: (value) => name = value,
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        initialValue: description,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        onChanged: (value) => description = value,
                      ),
                      const SizedBox(height: 16),

                      // Billing Type Dropdown
                      DropdownButtonFormField<String>(
                        value: billingType,
                        decoration: InputDecoration(
                          labelText: 'Billing Type',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'one-time',
                            child: Text('One Time'),
                          ),
                          DropdownMenuItem(
                            value: 'recurring',
                            child: Text('Recurring'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            billingType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Billing Interval (only visible for recurring)
                      if (billingType == 'recurring')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Billing Interval (months)',
                              style: GoogleFonts.questrial(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        if (billingInterval > 1) {
                                          billingInterval--;
                                        }
                                      });
                                    },
                                  ),
                                  Container(
                                    width: 60,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      billingInterval.toString(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.questrial(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        billingInterval++;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                      // Base Price Field
                      TextFormField(
                        initialValue: basePrice.toString(),
                        decoration: InputDecoration(
                          labelText: 'Base Price (₹)',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter base price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          basePrice = double.tryParse(value) ?? 0.0;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.questrial(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  // Show loading indicator
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    ),
                                  );

                                  // Call the API for adding the service here
                                  final success = await addService(
                                    name: name,
                                    description: description,
                                    billingType: billingType,
                                    billingInterval: billingInterval,
                                    basePrice: basePrice,
                                  );

                                  // Close loading indicator
                                  if (mounted) Navigator.of(context).pop();

                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$name added successfully',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    Navigator.of(
                                      context,
                                    ).pop(); // Close the add dialog
                                    fetchServices(); // Refresh the services list
                                  }
                                } catch (e) {
                                  // Close loading indicator if still mounted
                                  if (mounted) Navigator.of(context).pop();

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to add service: ${e.toString().replaceAll('Exception: ', '')}',
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: Text(
                              'Add',
                              style: GoogleFonts.questrial(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
      },
    );
  }

  Future<void> _showEditServiceDialog(dynamic service) async {
    final _formKey = GlobalKey<FormState>();

    // Local variables to hold form data
    String name = service['name']?.toString() ?? '';
    String description = service['description']?.toString() ?? '';
    String billingType = service['billing_type']?.toString() ?? 'one_time';
    int billingInterval = service['billing_interval'] != null
        ? int.tryParse(service['billing_interval'].toString()) ?? 1
        : 1;
    double basePrice = service['base_price'] != null
        ? double.tryParse(service['base_price'].toString()) ?? 0.0
        : 0.0;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Service',
                        style: GoogleFonts.questrial(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name Field
                      TextFormField(
                        initialValue: name,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter service name';
                          }
                          return null;
                        },
                        onChanged: (value) => name = value,
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        initialValue: description,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        onChanged: (value) => description = value,
                      ),
                      const SizedBox(height: 16),

                      // Billing Type Dropdown
                      DropdownButtonFormField<String>(
                        value: billingType,
                        decoration: InputDecoration(
                          labelText: 'Billing Type',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        dropdownColor: Colors.white,
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'one-time',
                            child: Text('One Time'),
                          ),
                          DropdownMenuItem(
                            value: 'recurring',
                            child: Text('Recurring'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            billingType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Billing Interval (only visible for recurring)
                      if (billingType == 'recurring')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Billing Interval (months)',
                              style: GoogleFonts.questrial(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        if (billingInterval > 1) {
                                          billingInterval--;
                                        }
                                      });
                                    },
                                  ),
                                  Container(
                                    width: 60,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      billingInterval.toString(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.questrial(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        billingInterval++;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                      // Base Price Field
                      TextFormField(
                        initialValue: basePrice.toString(),
                        decoration: InputDecoration(
                          labelText: 'Base Price (₹)',
                          labelStyle: GoogleFonts.questrial(
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: GoogleFonts.questrial(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter base price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          basePrice = double.tryParse(value) ?? 0.0;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.questrial(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                try {
                                  // Show loading indicator
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    ),
                                  );

                                  // Call the update API
                                  final success = await updateService(
                                    serviceId: service['id'],
                                    name: name,
                                    description: description,
                                    billingType: billingType,
                                    billingInterval: billingInterval,
                                    basePrice: basePrice,
                                  );

                                  // Close loading indicator
                                  if (mounted) Navigator.of(context).pop();

                                  if (success && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '$name updated successfully',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    Navigator.of(
                                      context,
                                    ).pop(); // Close the edit dialog
                                    fetchServices(); // Refresh the services list
                                  }
                                } catch (e) {
                                  // Close loading indicator if still mounted
                                  if (mounted) Navigator.of(context).pop();

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update service: ${e.toString().replaceAll('Exception: ', '')}',
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: Text(
                              'Update',
                              style: GoogleFonts.questrial(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
      },
    );
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
          "Services",
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
                  // Add extra padding at the bottom for the floating button
                  SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 0), // Position above bottom nav
        child: FloatingActionButton(
          onPressed: () {
            _showAddServiceDialog();
          },
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
          elevation: 4,
          shape: CircleBorder(), // Ensures perfect circle
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
          currentIndex: 1,
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
              icon: Icon(Icons.autorenew),
              label: 'Renewals',
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
    final bool isActive = service['is_active'] == 1;
    final Color statusColor = isActive ? Colors.green : Colors.grey;
    final String serviceName = service['name']?.toString() ?? 'No Name';
    final int serviceId = service['id'];

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
                GestureDetector(
                  onTap: () => _showEditServiceDialog(service),
                  child: const Icon(Icons.edit, size: 15, color: Colors.grey),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () =>
                      _showDeleteConfirmationDialog(serviceName, serviceId),
                  child: const Icon(
                    Icons.delete,
                    size: 15,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      // Wrap this with Padding widget
                      padding: const EdgeInsets.only(
                        right: 15,
                      ), // Optional: add any padding as needed
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

  Future<void> _showDeleteConfirmationDialog(
    String serviceName,
    int serviceId,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Set background color to white
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              12.0,
            ), // Optional: rounded corners
          ),
          title: Text(
            'Delete "$serviceName"',
            style: GoogleFonts.questrial(
              fontWeight: FontWeight.bold,
              color: Colors.black, // Ensure text is visible on white background
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$serviceName" service?',
            style: GoogleFonts.questrial(
              color: Colors.black, // Ensure text is visible on white background
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.questrial(color: Colors.grey[600]),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Delete',
                style: GoogleFonts.questrial(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteService(serviceId);
              },
            ),
          ],
        );
      },
    );
  }
}
