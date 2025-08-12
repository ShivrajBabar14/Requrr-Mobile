import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FCMTokenService {
  static const String baseUrl = 'https://requrr.com/api/fcm-token';
  
  // Helper function to validate platform
  static String _validatePlatform(String platform) {
    const validPlatforms = ['android', 'iOS', 'web'];
    return validPlatforms.contains(platform) ? platform : 'unknown';
  }

  // Detect platform based on device
  static Future<String> _getPlatform() async {
    // For Flutter apps, we can use platform detection
    // This is a simplified version - you might want to use platform package
    return 'android'; // Default to android for now
  }

  // Store or update FCM token
  static Future<bool> storeFCMToken(String authToken, String userId) async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      
      if (fcmToken == null) {
        print('FCM token is null');
        return false;
      }

      final platform = await _getPlatform();
      final validatedPlatform = _validatePlatform(platform);
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'user_id': userId,
          'platform': validatedPlatform,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('FCM token stored successfully');
        
        // Save token locally for future reference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
        await prefs.setString('user_id', userId);
        
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
  static Future<Map<String, dynamic>?> getFCMToken(String authToken, String userId, {String? platform}) async {
    try {
      final params = {'user_id': userId};
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
  static Future<List<dynamic>> getAllFCMTokens(String authToken, String userId) async {
    try {
      final uri = Uri.parse('$baseUrl/all?user_id=$userId');
      
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
  static Future<bool> deleteFCMToken(String authToken, String userId, {String platform = 'android'}) async {
    try {
      final validatedPlatform = _validatePlatform(platform);
      
      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'user_id': userId,
          'platform': validatedPlatform,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token deleted successfully');
        
        // Clear local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fcm_token');
        await prefs.remove('user_id');
        
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
  static Future<bool> updateFCMToken(String authToken, String userId, {String platform = 'android'}) async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      
      if (fcmToken == null) {
        print('FCM token is null');
        return false;
      }

      final validatedPlatform = _validatePlatform(platform);
      
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': fcmToken,
          'user_id': userId,
          'platform': validatedPlatform,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token updated successfully');
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
        
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

  // Initialize FCM token sync on app start
  static Future<void> initializeFCMSync(String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId != null) {
        await storeFCMToken(authToken, userId);
      }
      
      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (userId != null) {
          await updateFCMToken(authToken, userId);
        }
      });
    } catch (e) {
      print('Error initializing FCM sync: $e');
    }
  }
}
