import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'auth_service.dart';
import 'forgotpassword.dart';
import 'registerform.dart';
import 'dashboard.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fcm_api_service.dart';

// Add UserService definition for storing userId
class UserService {
  static Future<void> storeUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  /* ------------------------------------------------------------- */
  /* -------------------------- API CALL -------------------------- */
  /* ------------------------------------------------------------- */
  Future<void> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email and password are required!'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://requrr.com/api/auth/login');
      final client = http.Client();
      var resp = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      // Handle 307 redirect if present
      if (resp.statusCode == 307 && resp.headers['location'] != null) {
        resp = await client.post(
          Uri.parse(resp.headers['location']!),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );
      }

      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);

        if (data['token'] != null) {
          final token = data['token'] as String;
          await _authService.saveTokens(token, token);

          // Fetch user profile to get first_name
          final userProfile = await _fetchUserProfile(token);
          final firstName = userProfile?['first_name'] ?? '';

          // Store FCM token after successful login
          await _storeFCMToken(token, email);

          await _showLoginNotification(firstName);

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => Dashboard(token: token)),
          );
        } else {
          _showError('Token not found in response.');
        }
      } else {
        _showError('Something went wrong. Please try again.');
      }
    } catch (e) {
      _showError('Error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _storeFCMToken(String authToken, String userEmail) async {
    try {
      // Extract user ID from JWT token (same as sidebar.dart)
      Map<String, dynamic> decodedToken = JwtDecoder.decode(authToken);
      final userId = decodedToken['id']?.toString();

      if (userId == null || userId.isEmpty) {
        print('User ID not found in JWT token, cannot store FCM token');
        return;
      }

      // Store user ID for future use
      await UserService.storeUserId(userId);

      // Store FCM token using user ID
      final success = await FCMApiService.storeFCMToken(userId);

      if (success) {
        print('FCM token stored successfully for user ID: $userId');
      } else {
        print('Failed to store FCM token for user ID: $userId');
      }
    } catch (e) {
      print('Error storing FCM token: $e');
      // Don't fail login if FCM storage fails
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://requrr.com/api/me'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userData", jsonEncode(data));
        return data;
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  Future<void> _showLoginNotification(String firstName) async {
    // Request permission on Android 13+
    await Permission.notification.request();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(settings);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'login_channel',
          'Login Notifications',
          channelDescription: 'Channel for login notification',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final message = firstName.isNotEmpty
        ? '$firstName, you have logged in to Requrr'
        : 'You have logged in to Requrr';

    await _notificationsPlugin.show(
      0,
      'Login Successful',
      message,
      notificationDetails,
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.black));

  /* ------------------------------------------------------------- */
  /* ---------------------------  UI  ----------------------------- */
  /* ------------------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ---------- TOP PATTERNED HEADER ----------
          Container(
            height: size.height * 0.4,
            width: size.width,
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  20,
                ), // Change radius as needed
                child: Image.asset(
                  'assets/appicon.png', // <-- your white logo mark
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover, // Ensures it respects the border shape
                ),
              ),
            ),
          ),

          // ---------- SCROLLABLE FORM SHEET ----------
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: size.height * 0.32, // start overlapping header
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------------- HEADLINE --------------
                    Text(
                      'Login',
                      style: GoogleFonts.questrial(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // -------------- EMAIL FIELD --------------
                    _StyledField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    // -------------- PASSWORD FIELD --------------
                    _StyledField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscure: !_isPasswordVisible,
                      suffix: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // -------------- SIGN‑IN BUTTON --------------
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : login,
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
                                  'Login',
                                  style: GoogleFonts.questrial(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // -------------- FORGOT PASSWORD --------------
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.questrial(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // -------------- SIGN‑UP PROMPT --------------
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.questrial(color: Colors.black54),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            WidgetSpan(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SignUpPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Sign Up',
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
}

/* ---------------------------------------------------------------- */
/* -------------------- REUSABLE STYLED FIELD --------------------- */
/* ---------------------------------------------------------------- */
class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
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
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
