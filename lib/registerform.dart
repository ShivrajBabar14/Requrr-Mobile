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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if the response message indicates an error
        if (data['message'] == 'Error') {
          // Show the error message (Gmail already registered)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gmail is already registered')),
          );
        } else if (data['message'] == 'success') {
          // Show the success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Registration successful!')),
          );

          // Reset the form after a successful registration
          Future.delayed(Duration(seconds: 1), () {
            _formKey.currentState?.reset();
            _firstNameController.clear();
            _lastNameController.clear();
            _emailController.clear();
            _mobileController.clear();
            _passwordController.clear();
            _selectedCountryCode = null;  // Optionally clear country selection
          });
        }
      } else {
        // Handle failed request
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.reasonPhrase}")),
        );
      }
    } catch (e) {
      // Handle errors in case of exceptions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            title: Text(
              'Sign Up',
              style: GoogleFonts.questrial(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              // Firstname & Lastname
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'Firstname',
                      icon: Icons.person_outline,
                      readOnly: false,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Lastname',
                      readOnly: false,
                      enabled: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Email
              _buildTextField(
                controller: _emailController,
                label: 'Email address',
                icon: Icons.email_outlined,
                readOnly: false,
                enabled: true,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Country Picker
              _buildCountryPickerField(),
              const SizedBox(height: 20),

              // Mobile
              _buildTextField(
                controller: _mobileController,
                label: 'Mobile Number',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // Password
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 40),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _submitForm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SIGN UP',
                        style: GoogleFonts.questrial(
                            fontSize: 16, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, color: Colors.white),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool readOnly = false,
    bool isPassword = false,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: isPassword ? _obscurePassword : false,
      cursorColor: Colors.blueAccent,
      keyboardType: keyboardType,
      style: GoogleFonts.questrial(),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.questrial(color: Colors.grey),
        hintStyle: GoogleFonts.questrial(color: Colors.grey),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
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
              prefixIcon: Icon(Icons.search),
              labelStyle: GoogleFonts.questrial(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 0),
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
          prefixIcon: Icon(Icons.flag_outlined, color: Colors.grey),
          labelStyle: GoogleFonts.questrial(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent),
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
