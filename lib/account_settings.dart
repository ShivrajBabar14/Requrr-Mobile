import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _confirmedDelete = false;

  final Map<String, dynamic> _formData = {
    'username': '',
    'email': '',
    'first_name': '',
    'last_name': '',
    'country_code': '',
    'phone_code': '',
    'phone': '',
  };

  Map<String, dynamic>? _subscription;
  String _authToken = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please login again.'),
          ),
        );
      }
      return;
    }

    _authToken = token;

    try {
      // Load user data
      final userRes = await http.get(
        Uri.parse("https://requrr-web-v2.vercel.app/api/me"),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (userRes.statusCode == 200) {
        final userData = json.decode(userRes.body);
        setState(() {
          _formData['username'] = userData['username'] ?? '';
          _formData['email'] = userData['email'] ?? '';
          _formData['first_name'] = userData['first_name'] ?? '';
          _formData['last_name'] = userData['last_name'] ?? '';
          _formData['country_code'] = userData['country_code'] ?? '';
          _formData['phone_code'] = userData['phone_code'] ?? '';
          _formData['phone'] = userData['phone'] ?? '';
        });
      }

      // Load subscription
      final subRes = await http.get(
        Uri.parse("https://requrr-web-v2.vercel.app/api/subscription/status"),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (subRes.statusCode == 200) {
        final subData = json.decode(subRes.body);
        if (subData['subscribed'] == true) {
          setState(() {
            _subscription = subData;
          });
        }
      }
    } catch (e) {
      print("Error loading data: $e");
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _updatePhoneCode(String countryCode) {
    // Map of country codes to phone codes
    final countryPhoneCodes = {
      'US': '1',
      'GB': '44',
      'CA': '1',
      'AU': '61',
      'IN': '91',
      'DE': '49',
      'FR': '33',
      'IT': '39',
      'ES': '34',
      'BR': '55',
      'MX': '52',
      'JP': '81',
      'CN': '86',
      'KR': '82',
      'RU': '7',
      'ZA': '27',
      'NG': '234',
      'KE': '254',
      'EG': '20',
    };

    setState(() {
      _formData['phone_code'] = countryPhoneCodes[countryCode] ?? '1';
    });
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final response = await http.put(
        Uri.parse("https://requrr-web-v2.vercel.app/api/users/update-profile"),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(_formData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated successfully!')),
        );
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['error'] ?? 'Update failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Confirm Account Deletion',
                style: GoogleFonts.questrial(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.questrial(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.questrial(
                        color: Colors.white,
                        fontSize: 16,
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

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse("https://requrr-web-v2.vercel.app/api/users/delete-account"),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully!')),
        );

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['error'] ?? 'Delete failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black),)));
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Information',
                        style: GoogleFonts.questrial(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StyledTextFormField(
                        initialValue: _formData['username'],
                        label: 'Username',
                        icon: Icons.person_outline,
                        onChanged: (value) => _formData['username'] = value,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Username is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _StyledTextFormField(
                        initialValue: _formData['email'],
                        label: 'Email',
                        icon: Icons.email_outlined,
                        onChanged: (value) => _formData['email'] = value,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Email is required';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (!emailRegex.hasMatch(value!)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StyledTextFormField(
                              initialValue: _formData['first_name'],
                              label: 'First Name',
                              icon: Icons.person_outline,
                              onChanged: (value) =>
                                  _formData['first_name'] = value,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StyledTextFormField(
                              initialValue: _formData['last_name'],
                              label: 'Last Name',
                              icon: Icons.person_outline,
                              onChanged: (value) =>
                                  _formData['last_name'] = value,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
              // Country Selection
              _StyledTextFormField(
                initialValue: _formData['country_code'],
                label: 'Country',
                icon: Icons.public_outlined,
                onChanged: (value) {
                  _formData['country_code'] = value;
                  // Auto-update phone code based on country
                  _updatePhoneCode(value);
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Number with Country Code
              Row(
                children: [
                  Container(
                    width: 80,
                    child: TextFormField(
                      initialValue: _formData['phone_code'],
                      onChanged: (value) => _formData['phone_code'] = value,
                      cursorColor: Colors.black,
                      style: GoogleFonts.questrial(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Code',
                        labelStyle: GoogleFonts.questrial(color: Colors.grey),
                        floatingLabelStyle: GoogleFonts.questrial(color: Colors.black),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StyledTextFormField(
                      initialValue: _formData['phone'],
                      label: 'Phone Number',
                      icon: Icons.phone_android_outlined,
                      onChanged: (value) => _formData['phone'] = value,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _handleUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save Changes'),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: () => _loadUserData(),
                            style: OutlinedButton.styleFrom(
                             
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black),
                            ),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Subscription Section
              if (_subscription != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Subscription',
                          style: GoogleFonts.questrial(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Plan', _subscription!['plan_name']),
                        _buildInfoRow(
                          'Start Date',
                          _formatDate(_subscription!['start_date']),
                        ),
                        _buildInfoRow(
                          'End Date',
                          _formatDate(_subscription!['end_date']),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Delete Account Section
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Account',
                        style: GoogleFonts.questrial(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This action is permanent and cannot be undone.',
                        style: GoogleFonts.questrial(color: Colors.black),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _confirmedDelete,
                            onChanged: (value) {
                              setState(() {
                                _confirmedDelete = value ?? false;
                              });
                            },
                            checkColor: Colors.black, // Tick color
                            activeColor: Colors.white, // Background when checked
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),

                          Expanded(
                            child: Text(
                              'I confirm my account deletion',
                              style: GoogleFonts.questrial(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _confirmedDelete ? _handleDelete : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Delete Account'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}

class _StyledTextFormField extends StatelessWidget {
  const _StyledTextFormField({
    required this.initialValue,
    required this.label,
    required this.icon,
    this.onChanged,
    this.validator,
    this.keyboardType,
  });

  final String initialValue;
  final String label;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      cursorColor: Colors.black,
      style: GoogleFonts.questrial(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.questrial(color: Colors.grey),
        floatingLabelStyle: GoogleFonts.questrial(color: Colors.black),
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
