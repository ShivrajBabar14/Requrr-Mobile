import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'forgotpassword.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final AuthService _authService = AuthService();

  Future<void> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email and password are required!"),
          backgroundColor: Colors.blueAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('https://requrr.com/api/auth/login');

      var client = http.Client();

      var response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // Check for 307 status code (redirect)
      if (response.statusCode == 307) {
        final location = response.headers['location'];
        if (location != null) {
          print("Redirecting to: $location");

          final redirectUrl = Uri.parse(location);
          response = await client.post(
            redirectUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          );
        }
      }

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final responseData = jsonDecode(response.body);

          // Check if the token is available in the response
          if (responseData.containsKey('token')) {
            final accessToken = responseData['token'];

            if (accessToken != null) {
              print('Access Token: $accessToken');

              // Save the token (assuming your method expects it)
              await _authService.saveTokens(accessToken, accessToken);

              // Navigate to next screen (e.g., Dashboard) passing token
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => Dashboard(token: accessToken),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Token not found in response."),
                  backgroundColor: Colors.blueAccent,
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Invalid response format."),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }
        } catch (e) {
          print('Error while decoding response body: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error occurred: $e"),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      } else {
        // Handling other status codes (non-200)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong. Please try again."),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      print('Error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error occurred: $e"),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        // Add this to make it scrollable if the keyboard appears
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // blueAccentuced top margin
              const SizedBox(height: 70), // blueAccentuced space from the top
              // Login Title
              Text("Login", style: GoogleFonts.questrial(fontSize: 24)),

              const SizedBox(
                height: 40,
              ), // Spacing between title and input fields
              // Email input
              TextField(
                controller: _emailController,
                style: GoogleFonts.questrial(color: Colors.black),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.grey,
                  ),
                  labelText: "Email",
                  labelStyle: GoogleFonts.questrial(color: Colors.grey),
                  floatingLabelStyle: GoogleFonts.questrial(
                    color: Colors.blueAccent,
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  hoverColor: Colors.blueAccent,
                ),
                cursorColor: Colors.blueAccent,
              ),
              const SizedBox(height: 20),

              // Password input
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: GoogleFonts.questrial(color: Colors.black),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.grey,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  labelText: "Password",
                  floatingLabelStyle: GoogleFonts.questrial(
                    color: Colors.blueAccent,
                  ),
                  labelStyle: GoogleFonts.questrial(color: Colors.grey),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  hoverColor: Colors.blueAccent,
                ),
                cursorColor: Colors.blueAccent,
              ),
              const SizedBox(height: 40),

              // Sign in button
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 100,
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "SIGN IN",
                              style: GoogleFonts.questrial(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_right_alt, color: Colors.white),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Forgot password link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "Forgot password?",
                    style: GoogleFonts.questrial(color: Colors.blueAccent),
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
