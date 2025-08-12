import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class UserService {
  // Extract user ID from JWT token
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      if (token != null) {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        return decodedToken['sub']?.toString() ?? decodedToken['id']?.toString();
      }
      return null;
    } catch (e) {
      print('Error extracting user ID: $e');
      return null;
    }
  }

  // Store user ID in shared preferences
  static Future<void> storeUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
    } catch (e) {
      print('Error storing user ID: $e');
    }
  }

  // Get user ID from shared preferences
  static Future<String?> getStoredUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (e) {
      print('Error getting stored user ID: $e');
      return null;
    }
  }

  // Extract user data from JWT token
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      
      if (token != null) {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        return decodedToken;
      }
      return null;
    } catch (e) {
      print('Error extracting user data: $e');
      return null;
    }
  }
}
