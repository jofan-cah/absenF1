import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _prefs!.setString('auth_token', token);
  }

  Future<String?> getToken() async {
    return _prefs!.getString('auth_token');
  }

  Future<void> removeToken() async {
    await _prefs!.remove('auth_token');
  }

  // User data management
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _prefs!.setString('user_data', jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final userData = _prefs!.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  Future<void> removeUserData() async {
    await _prefs!.remove('user_data');
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs!.clear();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
