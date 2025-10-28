import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/constants.dart';

class FCMService {
  // Ganti dengan URL Laravel kamu
  // static const String baseUrl = ; // contoh: http://192.168.1.100
  
  /// Save FCM token ke server setelah login
  static Future<bool> saveTokenToServer(String authToken) async {
    try {
      // Get FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken == null) {
        print('❌ FCM Token is null');
        return false;
      }
      
      print('📤 Saving token to server: ${fcmToken.substring(0, 20)}...');
      
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/device/device-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'device_token': fcmToken,
          'device_type': 'android',
          'device_name': 'Flutter App',
        }),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Token saved to server successfully');
        return true;
      } else {
        print('❌ Failed to save token: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error saving token: $e');
      return false;
    }
  }
  
  /// Delete token dari server (saat logout)
  static Future<bool> deleteTokenFromServer(String authToken) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken == null) return false;
      
      final response = await http.delete(
          Uri.parse('${AppConstants.baseUrl}/device/device-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_token': fcmToken,
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Token deleted from server');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ Error deleting token: $e');
      return false;
    }
  }
}