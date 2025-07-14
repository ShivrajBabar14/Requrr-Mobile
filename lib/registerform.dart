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

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedCountryCode;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.lastName ?? '');
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final Map<String, dynamic> formData = {
        "firstName": _firstNameController.text.trim(),
        "lastName": _lastNameController.text.trim(),
        "email": _emailController.text.trim(),
        "mobile": _mobileController.text.trim(),
        "password": _passwordController.text.trim(),
        "country": _selectedCountryCode,
      };

      try {
        final response = await http.post(
          Uri.parse('https://api.camrilla.com/user/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formData),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['message'] == 'Error') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gmail is already registered'),
                backgroundColor: Colors.black,
              ),
            );
          } else if (data['message'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration successful!'),
                backgroundColor: Colors.black,
              ),
            );

            Future.delayed(const Duration(seconds: 1), () {
              _formKey.currentState?.reset();
              _firstNameController.clear();
              _lastNameController.clear();
              _emailController.clear();
              _mobileController.clear();
              _passwordController.clear();
              _selectedCountryCode = null;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed: ${response.reasonPhrase}"),
              backgroundColor: Colors.black,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.black),
        );
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
          // Background pattern (matching login.dart)
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

          // Form content
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

                    // Firstname & Lastname
                    Row(
                      children: [
                        Expanded(
                          child: _StyledField(
                            controller: _firstNameController,
                            label: 'Firstname',
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _StyledField(
                            controller: _lastNameController,
                            label: 'Lastname',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Email
                    _StyledField(
                      controller: _emailController,
                      label: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    // Country Picker
                    _buildCountryPickerField(),
                    const SizedBox(height: 20),

                    // Mobile
                    _StyledField(
                      controller: _mobileController,
                      label: 'Mobile Number',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),

                    // Password
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
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sign Up Button
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

                    // Login prompt
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
          showPhoneCode: false,
          countryListTheme: CountryListThemeData(
            bottomSheetHeight: 400,
            textStyle: GoogleFonts.questrial(),
            inputDecoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Start typing to search',
              prefixIcon: const Icon(Icons.search),
              labelStyle: GoogleFonts.questrial(color: Colors.grey),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 0,
              ),
            ),
          ),
          onSelect: (Country country) {
            setState(() {
              _selectedCountryCode = country.countryCode;
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

// Reusable styled field matching login.dart
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
