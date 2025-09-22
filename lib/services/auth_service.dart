// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class AuthService {
  late Dio _dio;
  late StorageService _storage;

  AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
    ));
    
    _initStorage();
    _setupInterceptors();
  }

  Future<void> _initStorage() async {
    _storage = await StorageService.getInstance();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add token to header if available
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          options.headers['Content-Type'] = 'application/json';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired, clear storage
            _storage.clearAll();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> login(String nip, String password) async {
    try {
      final response = await _dio.post(
        AppConstants.loginEndpoint,
        data: {
          'nip': nip,
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        // Save token and user data
        await _storage.saveToken(response.data['data']['token']);
        await _storage.saveUserData(response.data['data']);
        
        return {
          'success': true,
          'message': response.data['message'],
          'data': response.data['data'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Login gagal',
        };
      }
    } on DioException catch (e) {
      String message = 'Terjadi kesalahan';
      
      if (e.response != null) {
        message = e.response!.data['message'] ?? 'Login gagal';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        message = 'Koneksi timeout';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        message = 'Server tidak merespons';
      } else {
        message = 'Tidak ada koneksi internet';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      await _dio.post(AppConstants.logoutEndpoint);
    } catch (e) {
      // Ignore error, just clear local data
    } finally {
      await _storage.clearAll();
    }
    
    return {
      'success': true,
      'message': 'Logout berhasil',
    };
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _dio.get(AppConstants.meEndpoint);
      
      return {
        'success': true,
        'data': response.data['data'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Gagal mengambil data user',
      };
    }
  }

  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }
}
