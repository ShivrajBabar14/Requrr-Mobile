import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';


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
        title: Text(
          "Forgot Password",
          style: GoogleFonts.questrial(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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
                style: GoogleFonts.questrial(color: Colors.blueAccent, fontSize: 14),
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
      cursorColor: Colors.blueAccent,
      style: GoogleFonts.questrial(
        color: Colors.black,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email, color: Colors.grey),
        labelText: "Email address",
        labelStyle: GoogleFonts.questrial(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("SUBMIT", style: GoogleFonts.questrial(color: Colors.white, fontSize: 16)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward, color: Colors.white),
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

    setState(() {
      _isLoading = true;
    });

    var url = Uri.parse('https://api.camrilla.com/n/api/auth/reset-password'); // fixed double slash
    var body = jsonEncode({"email": email});

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        _showMessage(data["message"] ?? "Password reset link sent!");
      } else {
        var errorData = jsonDecode(response.body);
        _showMessage(errorData["message"] ?? "Something went wrong!");
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showMessage("Error occurred: $error");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
