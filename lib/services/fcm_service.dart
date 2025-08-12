import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FCMService {
  static const String baseUrl = 'https://requrr-web-v2.vercel.app/api/fcm-token'; // Replace with your actual API endpoint
  
  static Future<String?> getFCMToken() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  static Future<bool> storeFCMToken(String token, String userEmail) async {
    try {
      final fcmToken = await getFCMToken();
      if (fcmToken == null) {
        print('FCM token is null');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/store-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': userEmail,
          'fcm_token': fcmToken,
          'platform': 'mobile',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('FCM token stored successfully');
        
        // Save token locally for future reference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
        
        return true;
      } else {
        print('Failed to store FCM token: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error storing FCM token: $e');
      return false;
    }
  }

  static Future<bool> updateFCMToken(String token, String userEmail) async {
    try {
      final fcmToken = await getFCMToken();
      if (fcmToken == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/update-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': userEmail,
          'fcm_token': fcmToken,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }
}
