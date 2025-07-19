import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_picker/country_picker.dart';

class SignUpPage extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String? email;

  const SignUpPage({Key? key, this.firstName, this.lastName, this.email})
    : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _fullNameController = TextEditingController();
  late TextEditingController _emailController;
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedCountryCode;
  String? _selectedPhoneCode;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
        return;
      }

      setState(() => _isLoading = true);

      final nameParts = _fullNameController.text.trim().split(' ');
      String firstName = nameParts.isNotEmpty ? nameParts.first : '';
      String lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      final Map<String, dynamic> formData = {
        "first_name": firstName,
        "last_name": lastName,
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        "country_code": _selectedCountryCode ?? '',
        "phone_code": _selectedPhoneCode ?? '',
        "phone": _mobileController.text.trim(),
      };

      try {
        final response = await http.post(
          Uri.parse('https://www.requrr.com/api/auth/signup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formData),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200 && data['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']),
              backgroundColor: Colors.black,
            ),
          );

          if (data['message'].toLowerCase().contains('success')) {
            // Clear form fields
            _formKey.currentState?.reset();
            _fullNameController.clear();
            _emailController.clear();
            _mobileController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
            setState(() {
              _selectedCountryCode = null;
              _selectedPhoneCode = null;
            });

            Future.delayed(const Duration(seconds: 2), () {
              Navigator.of(context).pushReplacementNamed('/login');
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Signup failed")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: size.height * 0.2,
            width: size.width,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: size.height * 0.15,
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Account',
                      style: GoogleFonts.questrial(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),

                    _StyledField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),

                    _StyledField(
                      controller: _emailController,
                      label: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    _buildCountryPickerField(),
                    const SizedBox(height: 20),

                    _StyledField(
                      controller: _mobileController,
                      label: 'Phone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),

                    _StyledField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _StyledField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscure: true,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'SIGN UP',
                                style: GoogleFonts.questrial(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.questrial(color: Colors.black54),
                          children: [
                            const TextSpan(text: "Already have an account? "),
                            WidgetSpan(
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  'Login',
                                  style: GoogleFonts.questrial(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryPickerField() {
    return GestureDetector(
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: true,
          onSelect: (Country country) {
            setState(() {
              _selectedCountryCode = country.countryCode;
              _selectedPhoneCode = "+${country.phoneCode}";
            });
          },
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Country',
          prefixIcon: const Icon(Icons.flag_outlined, color: Colors.grey),
          labelStyle: GoogleFonts.questrial(color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 2,
            horizontal: 12,
          ),
        ),
        child: Text(
          _selectedCountryCode != null
              ? _getCountryNameFromCode(_selectedCountryCode!)
              : 'Select a country',
          style: GoogleFonts.questrial(
            color: _selectedCountryCode != null ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  String _getCountryNameFromCode(String code) {
    final country = Country.tryParse(code);
    return country?.name ?? code;
  }
}

// Reusable styled field
class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: Colors.black,
      style: GoogleFonts.questrial(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.questrial(color: Colors.grey),
        floatingLabelStyle: GoogleFonts.questrial(color: Colors.black),
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
