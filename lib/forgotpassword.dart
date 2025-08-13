import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';

void main() {
  runApp(const ForgotPasswordScreen());
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ForgotPasswordPage(),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          ),
        ),
        title: Text(
          "Forgot Password",
          style: GoogleFonts.questrial(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Enter email id to receive your password",
                style: GoogleFonts.questrial(color: Colors.black, fontSize: 14),
              ),
            ),
            const SizedBox(height: 30),
            _buildEmailField(),
            const SizedBox(height: 40),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      cursorColor: Colors.black,
      style: GoogleFonts.questrial(color: Colors.black, fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email, color: Colors.grey),
        labelText: "Email address",
        labelStyle: GoogleFonts.questrial(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "SUBMIT",
                    style: GoogleFonts.questrial(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
      ),
    );
  }

  void _submitEmail() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage("Please enter your email address.");
      return;
    }

    setState(() => _isLoading = true);

    var url = Uri.parse(
      'https://requrr.com/api/users/forgot-password',
    ); // HTTPS to avoid redirect
    var body = jsonEncode({"email": email});

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print("Status Code: ${response.statusCode}");
      print("Body: ${response.body}");

      // Handle redirect manually if needed
      if (response.statusCode == 307 || response.statusCode == 308) {
        var redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          print("Redirecting to: $redirectUrl");
          response = await http.post(
            Uri.parse(redirectUrl),
            headers: {"Content-Type": "application/json"},
            body: body,
          );
          print("Redirect Response Code: ${response.statusCode}");
          print("Redirect Response Body: ${response.body}");
        }
      }

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        try {
          var data = jsonDecode(response.body);
          _showMessage(data["message"] ?? "Password reset link sent!");

          // ✅ Close the page automatically after 1 second
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          });
        } catch (_) {
          _showMessage("Password reset link sent!");
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          });
        }
      } else {
        try {
          var errorData = jsonDecode(response.body);
          _showMessage(errorData["message"] ?? "Something went wrong!");
        } catch (_) {
          _showMessage("Error: ${response.statusCode}");
        }
      }
    } catch (error) {
      setState(() => _isLoading = false);
      _showMessage("Error occurred: $error");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
