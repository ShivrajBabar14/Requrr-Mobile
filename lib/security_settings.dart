import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  _SecuritySettingsPageState createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _loading = false;
  String _message = '';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (newPasswordController.text != confirmPasswordController.text) {
      setState(() {
        _message = 'New and confirm passwords do not match';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = '';
    });

    final token = await _getToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _message = 'Unauthorized: No token found';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('https://requrr-web-v2.vercel.app/api/users/change-password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'currentPassword': currentPasswordController.text,
          'newPassword': newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _message = 'Password changed successfully!';
          currentPasswordController.clear();
          newPasswordController.clear();
          confirmPasswordController.clear();
        });
      } else {
        final data = json.decode(response.body);
        setState(() {
          _message = data['error'] ?? 'Failed to change password';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _styledInputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey.shade700),
      labelText: label,
      labelStyle: GoogleFonts.questrial(color: Colors.grey),
      floatingLabelStyle: GoogleFonts.questrial(color: Colors.black),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        'Change Password',
                        style: GoogleFonts.questrial(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: currentPasswordController,
                        decoration:
                            _styledInputDecoration('Current Password', Icons.lock_outline),
                        obscureText: true,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Enter current password'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        decoration:
                            _styledInputDecoration('New Password', Icons.vpn_key_outlined),
                        obscureText: true,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Enter new password' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: _styledInputDecoration(
                            'Confirm New Password', Icons.check_circle_outline),
                        obscureText: true,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Confirm new password' : null,
                      ),
                      const SizedBox(height: 24),
                      if (_message.isNotEmpty)
                        Text(
                          _message,
                          style: GoogleFonts.questrial(
                            color: _message.startsWith('Error') ||
                                    _message.startsWith('Failed')
                                ? Colors.red
                                : Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save, size: 18),
                            label: _loading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Changes'),
                            onPressed: _loading ? null : _handleChangePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reset'),
                            onPressed: () {
                              currentPasswordController.clear();
                              newPasswordController.clear();
                              confirmPasswordController.clear();
                              setState(() {
                                _message = '';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
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
}
