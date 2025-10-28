import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register.dart';
import 'dashboard.dart';
import 'login.dart';
import 'subscription.dart';
import 'recurring_expenses.dart';
import 'notification_preferences.dart';
import 'account_settings.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Import Google Fonts if used
import './services/notification_service.dart'; // ✅ Import your service

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [BG] Handling message: ${message.messageId}');
  // ✅ Optional: Show local notification here if needed
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Init NotificationService (sets up everything)
  await NotificationService.initialize();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    
    // Already handled inside NotificationService.initialize()
    // Just show token for debugging if needed
    FirebaseMessaging.instance.getToken().then((token) {
      print("🔑 FCM Token: $token");
    });
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      if (token != null && token.isNotEmpty) {
        // Validate token using the same logic as other parts of the app
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final jsonMap = json.decode(decoded);
          
          if (jsonMap['exp'] != null) {
            final expiryDate = DateTime.fromMillisecondsSinceEpoch(
              jsonMap['exp'] * 1000,
            );
            // Add 5-minute buffer to prevent false negatives
            final isValid = expiryDate.isAfter(DateTime.now().subtract(const Duration(minutes: 5)));
            
            if (isValid) {
              setState(() {
                _isAuthenticated = true;
                _authToken = token;
                _isLoading = false;
              });
              return;
            }
          }
        }
      }
      
      // If we get here, either no token or token is invalid
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking authentication status: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Enable deep navigation
      title: 'Requrr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        scaffoldBackgroundColor: Colors.white,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.redAccent.shade100,
          selectionHandleColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      routes: {
        '/register': (context) => Registration(),
        '/login': (context) => const LoginScreen(),
        '/subscription': (context) => SubscriptionPage(),
        '/recurring_expenses': (context) => RecurringExpensePage(),
        '/notification_preferences': (context) => const NotificationPreferencesPage(),
        '/account_settings': (context) => const AccountSettingsPage(),
      },
      home: _isAuthenticated ? Dashboard(token: _authToken) : const LoginScreen(),
    );
  }
}
