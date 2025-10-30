import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/version_service.dart'; 
import '../utils/constants.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AuthService _authService;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isVideoInitialized = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    
    _authService = AuthService();
    
    // Setup fade animation for fallback
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Initialize video player
      _videoController = VideoPlayerController.asset('assets/videos/F1C.mp4');
      
      await _videoController.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        
        // Play video
        _videoController.play();
        
        // Listen for video completion
        _videoController.addListener(_videoListener);
      }
    } catch (e) {
      print('Error initializing video: $e');
      // Fallback to static splash screen
      _fadeController.forward();
      _navigateAfterDelay();
    }
  }

  void _videoListener() {
    if (_videoController.value.position >= _videoController.value.duration) {
      // Video selesai, CEK VERSI DULU! ✅
      if (!_isNavigating) {
        _isNavigating = true;
        _checkVersionThenNavigate(); // GANTI INI
      }
    }
  }

  Future<void> _navigateAfterDelay() async {
    // Fallback navigation jika video gagal
    await Future.delayed(const Duration(seconds: 3));
    if (!_isNavigating) {
      _isNavigating = true;
      _checkVersionThenNavigate(); // GANTI INI
    }
  }

  // ✅ FUNGSI BARU: CEK VERSI DULU SEBELUM NAVIGASI
  Future<void> _checkVersionThenNavigate() async {
    try {
      // 1. CEK VERSI APP
      print('🔍 Checking app version...');
      final versionResult = await VersionService.checkVersion();
      
      if (!mounted) return;
      
      // 2. KALAU PERLU UPDATE
      if (versionResult['needUpdate'] == true) {
        print('⚠️ App needs update!');
        _showUpdateDialog(versionResult);
        return; // STOP DI SINI, GAK LANJUT KE LOGIN
      }
      
      // 3. KALAU VERSI OK, LANJUT CEK LOGIN
      print('✅ Version OK, checking login...');
      _checkLoginStatus();
      
    } catch (e) {
      print('❌ Error checking version: $e');
      // Kalau error cek versi, tetap lanjut (biar app gak hang)
      _checkLoginStatus();
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (mounted) {
        if (isLoggedIn) {
          // Check if token is still valid
          final result = await _authService.getMe();
          if (result['success'] == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          }
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking login status: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  // ✅ DIALOG UPDATE (GAK BISA DITUTUP)
  void _showUpdateDialog(Map<String, dynamic> info) {
    showDialog(
      context: context,
      barrierDismissible: false, // Gak bisa ditutup
      builder: (context) => PopScope(
        canPop: false, // Gak bisa back button
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update Diperlukan',
                  style: AppConstants.titleStyle.copyWith(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info['message'] ?? 'Aplikasi perlu diupdate',
                style: AppConstants.bodyStyle,
              ),
              const SizedBox(height: 16),
              
              // Info Versi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildVersionRow(
                      'Versi Anda',
                      info['currentVersion'],
                      Colors.red,
                    ),
                    const Divider(height: 16),
                    _buildVersionRow(
                      'Versi Minimum',
                      info['minimumVersion'],
                      Colors.orange,
                    ),
                    const Divider(height: 16),
                    _buildVersionRow(
                      'Versi Terbaru',
                      info['latestVersion'],
                      Colors.green,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aplikasi tidak bisa dibuka sebelum update',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Bisa ditambah logic download APK atau contact admin
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hubungi Admin IT untuk mendapatkan APK terbaru'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.contact_support),
                label: const Text('Hubungi Admin IT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionRow(String label, String version, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        Text(
          version,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          if (_isVideoInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),
          
          // Fallback Static Splash (jika video gagal load)
          if (!_isVideoInitialized)
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppConstants.paddingLarge),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        size: 80,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingLarge),
                    
                    Text(
                      AppConstants.appName,
                      style: AppConstants.titleStyle.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Sistem Absensi Karyawan',
                      style: AppConstants.bodyStyle.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingXLarge),
                    
                    const SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading...',
                      style: AppConstants.bodyStyle.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_isVideoInitialized && _videoController.value.isBuffering)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          
          // Skip button
          if (_isVideoInitialized)
            Positioned(
              top: 50,
              right: 20,
              child: SafeArea(
                child: TextButton(
                  onPressed: () {
                    if (!_isNavigating) {
                      _isNavigating = true;
                      _checkVersionThenNavigate(); // GANTI INI
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}