import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';

  Timer? _refreshTimer;

  // Save tokens to SharedPreferences
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Clear tokens
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    _refreshTimer?.cancel();
  }

  // Start the refresh timer
  void startTokenRefreshTimer(Duration expiresIn) {
    _refreshTimer?.cancel();
    Duration refreshDuration = expiresIn - const Duration(seconds: 20);
    if (refreshDuration.inSeconds <= 0) {
      refreshDuration = const Duration(seconds: 10);
    }

    print('Token refresh timer set for ${refreshDuration.inSeconds} seconds');
    _refreshTimer = Timer(refreshDuration, () async {
      print('Token refresh timer triggered');
      bool success = await refreshToken();
      if (!success) {
        print('Token refresh failed. Clearing tokens...');
        await clearTokens();
      } else {
        print('Token refresh succeeded');
      }
    });
  }

  Future<bool> tryRefreshToken() async {
    return await refreshToken();
  }

  // Refresh token API call
  Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAccessToken = prefs.getString(_accessTokenKey);
    final currentRefreshToken = prefs.getString(_refreshTokenKey);

    if (currentAccessToken == null || currentRefreshToken == null) {
      print('❌ Missing tokens in SharedPreferences');
      return false;
    }

    try {
      final url = Uri.parse('https://api.camrilla.com/user/update-access-token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': currentAccessToken,
          'refreshToken': currentRefreshToken,
        }),
      );

      print('🔄 Refresh token response status: ${response.statusCode}');
      print('🔄 Refresh token response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);

        if (body['code'] == 0 && body['data'] != null) {
          final data = body['data'];
          final tokenData = data['token'];

          if (tokenData is Map<String, dynamic>) {
            final newAccessToken = tokenData['accessToken'];
            final newRefreshToken = tokenData['refreshToken'];
            final accessTokenExpireIn = tokenData['accessTokenExpireIn'];

            if (newAccessToken is String &&
                newRefreshToken is String &&
                accessTokenExpireIn is int) {
              // ✅ Save new tokens
              await saveTokens(newAccessToken, newRefreshToken);

              // ✅ Restart timer with the new expiry
              startTokenRefreshTimer(Duration(seconds: accessTokenExpireIn));

              print('✅ Token refreshed successfully');
              return true;
            } else {
              print('❌ Token fields missing or invalid types');
            }
          } else {
            print('❌ "token" field is not a valid map');
          }
        } else {
          print('❌ API returned code ${body['code']} or missing data');
        }
      } else {
        print('❌ Token refresh failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception during token refresh: $e');
    }

    // If any step failed, clear tokens (optional)
    await clearTokens();
    return false;
  }

  // Authenticated POST with auto-retry on 401
  Future<http.Response> authenticatedPost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool retry = true,
  }) async {
    final accessToken = await getAccessToken();
    final updatedHeaders = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      if (headers != null) ...headers,
    };

    final response = await http.post(
      url,
      headers: updatedHeaders,
      body: body,
      encoding: encoding,
    );

    if (response.statusCode == 401 && retry) {
      print('401 Unauthorized detected. Trying token refresh...');
      final success = await refreshToken();
      if (success) {
        print('Retrying original request after token refresh...');
        return authenticatedPost(
          url,
          headers: headers,
          body: body,
          encoding: encoding,
          retry: false,
        );
      }
    }

    return response;
  }
}
