import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/constants.dart';

class VersionService {
  
  /// CEK VERSI APP
  static Future<Map<String, dynamic>> checkVersion() async {
    try {
      // 1. Ambil versi app dari pubspec.yaml
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version; // Contoh: "1.0.0"
      
      print('📱 Versi App Sekarang: $currentVersion');
      
      // 2. Hit API untuk ambil data versi dari server
      final dio = Dio();
      final response = await dio.get(AppConstants.versionCheckUrl);

      if (response.statusCode == 200) {
        final data = response.data['data'];
        
        String minimumVersion = data['minimum_version'];
        String latestVersion = data['latest_version'];
        bool forceUpdate = data['force_update'];
        String message = data['message'];
        
        print('🔥 Versi Minimum: $minimumVersion');
        print('🔥 Versi Terbaru: $latestVersion');
        
        // 3. Bandingkan versi (cek apakah perlu update)
        bool needUpdate = _compareVersion(currentVersion, minimumVersion) < 0;
        bool hasNewVersion = _compareVersion(currentVersion, latestVersion) < 0;
        
        return {
          'success': true,
          'needUpdate': needUpdate,           // true = versi terlalu lama
          'forceUpdate': forceUpdate && needUpdate, // true = WAJIB update
          'hasNewVersion': hasNewVersion,     // true = ada versi baru
          'currentVersion': currentVersion,
          'minimumVersion': minimumVersion,
          'latestVersion': latestVersion,
          'message': message,
          'downloadUrl': data['download_url'] ?? '',
        };
      }
      
    } catch (e) {
      print('❌ Error cek versi: $e');
    }
    
    // Kalau error API, biarkan app tetap jalan
    return {
      'success': false,
      'needUpdate': false,
      'forceUpdate': false,
    };
  }
  
  /// COMPARE VERSI (1.0.0 vs 1.2.0)
  /// Return: -1 jika v1 < v2, 0 jika sama, 1 jika v1 > v2
  static int _compareVersion(String v1, String v2) {
    List<int> v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    // Pastikan ada 3 bagian (major.minor.patch)
    while (v1Parts.length < 3) v1Parts.add(0);
    while (v2Parts.length < 3) v2Parts.add(0);
    
    for (int i = 0; i < 3; i++) {
      if (v1Parts[i] < v2Parts[i]) return -1; // v1 lebih kecil
      if (v1Parts[i] > v2Parts[i]) return 1;  // v1 lebih besar
    }
    return 0; // sama
  }
}