import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMApiService {
  static const String baseUrl = 'https://requrr-web-v2.vercel.app/api/fcm-token';
  
  // Helper function to validate platform
  static String validatePlatform(String platform) {
    const validPlatforms = ['android', 'iOS', 'web'];
    return validPlatforms.contains(platform) ? platform : 'android';
  }

  // Store or update FCM token
  static Future<bool> storeFCMToken(String userId, {String platform = 'android'}) async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      
      if (fcmToken == null) {
        print('FCM token is null');
        return false;
      }

      final validatedPlatform = validatePlatform(platform);
      
      // Print the exact payload being sent to terminal
      final payload = {
        'user_id': userId,
        'fcm_token': fcmToken,
        'platform': validatedPlatform,
      };
      
      print('=== FCM API REQUEST ===');
      print('URL: $baseUrl');
      print('Method: POST');
      print('Headers: {"Content-Type": "application/json"}');
      print('Payload: ${jsonEncode(payload)}');
      print('======================');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('=== FCM API RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('========================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('FCM token stored successfully');
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

  // Get FCM token for user
  static Future<Map<String, dynamic>?> getFCMToken(String authToken, String email, {String? platform}) async {
    try {
      final params = {'email': email};
      if (platform != null) {
        params['platform'] = platform;
      }

      final uri = Uri.parse('$baseUrl?${Uri(queryParameters: params).query}');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else if (response.statusCode == 404) {
        print('No token found for user');
        return null;
      } else {
        print('Failed to get FCM token: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Get all FCM tokens for user
  static Future<List<dynamic>> getAllFCMTokens(String authToken, String email) async {
    try {
      final uri = Uri.parse('$baseUrl/all?email=$email');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        print('Failed to get all FCM tokens: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting all FCM tokens: $e');
      return [];
    }
  }

  // Delete FCM token
  static Future<bool> deleteFCMToken(String authToken, String email, String platform) async {
    try {
      final validatedPlatform = validatePlatform(platform);
      
      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'email': email,
          'platform': validatedPlatform,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token deleted successfully');
        return true;
      } else {
        print('Failed to delete FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error deleting FCM token: $e');
      return false;
    }
  }

  // Update existing FCM token
  static Future<bool> updateFCMToken(String authToken, String email, String platform) async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      
      if (fcmToken == null) {
        print('FCM token is null');
        return false;
      }

      final validatedPlatform = validatePlatform(platform);
      
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'email': email,
          'platform': validatedPlatform,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token updated successfully');
        return true;
      } else {
        print('Failed to update FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }

  // Detect platform
  static Future<String> getPlatform() async {
    // For mobile apps, we can detect the platform
    // This is a simplified version - you might want to use platform package
    return 'android'; // Default to android, can be enhanced
  }
}
