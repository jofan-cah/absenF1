// lib/screens/absen_screen.dart - Modern UI
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/loading_widget.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen>
    with TickerProviderStateMixin {
  late Dio _dio;
  late StorageService _storage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Map<String, dynamic>? _absenData;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isProcessing = false;
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _initServices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initServices() async {
    _storage = await StorageService.getInstance();
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectionTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeout,
        ),
      ),
    );

    final token = await _storage.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _dio.options.headers['Accept'] = 'application/json';
    }

    await _loadAbsenData();
  }

  Future<void> _loadAbsenData() async {
    try {
      final response = await _dio.get(AppConstants.absenTodayEndpoint);

      if (response.data['success'] == true) {
        setState(() {
          _absenData = response.data['data'];
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showErrorSnackBar('Gagal memuat data absen: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus != PermissionStatus.granted) {
      _showPermissionDialog('Camera', 'untuk mengambil foto absen');
      return false;
    }

    final locationStatus = await Permission.location.request();
    if (locationStatus != PermissionStatus.granted) {
      _showPermissionDialog('Location', 'untuk mendeteksi lokasi absen');
      return false;
    }

    return true;
  }

  void _showPermissionDialog(String permission, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppConstants.warningColor),
            const SizedBox(width: 8),
            Text('Permission $permission'),
          ],
        ),
        content: Text(
          'Aplikasi memerlukan akses $permission $reason. Silakan berikan izin di pengaturan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Pengaturan'),
          ),
        ],
      ),
    );
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentAddress =
            'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      });

      return position;
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal mendapatkan lokasi: $e');
      }
      return null;
    }
  }

  Future<File?> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
      maxWidth: 1080,
      maxHeight: 1080,
    );

    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  // Update di absen_screen.dart - Bagian Clock In
  Future<void> _clockIn() async {
    if (!await _requestPermissions()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _currentPosition = await _getCurrentLocation();
      if (_currentPosition == null) {
        throw 'Gagal mendapatkan lokasi';
      }

      final photo = await _takePicture();
      if (photo == null) {
        throw 'Gagal mengambil foto';
      }

      // Get current time untuk debug
      final currentTime = TimeHelper.getCurrentTimeForServer();
      print('Current time being sent: $currentTime'); // Debug log

      FormData formData = FormData.fromMap({
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'address': _currentAddress,
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'clock_in_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        // Tambahkan timestamp lokal sebagai reference
        'local_time': currentTime,
        'timezone': DateTime.now().timeZoneName,
      });

      final response = await _dio.post(
        AppConstants.clockInEndpoint,
        data: formData,
      );

      if (response.data['success'] == true) {
        if (mounted) {
          _showSuccessSnackBar(response.data['message']);
        }
        await _loadAbsenData();
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Clock in gagal: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Update Clock Out juga sama
  Future<void> _clockOut() async {
    if (!await _requestPermissions()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _currentPosition = await _getCurrentLocation();
      if (_currentPosition == null) {
        throw 'Gagal mendapatkan lokasi';
      }

      final photo = await _takePicture();
      if (photo == null) {
        throw 'Gagal mengambil foto';
      }

      final currentTime = TimeHelper.getCurrentTimeForServer();
      print('Current time being sent: $currentTime'); // Debug log

      FormData formData = FormData.fromMap({
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'address': _currentAddress,
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'clock_out_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'local_time': currentTime,
        'timezone': DateTime.now().timeZoneName,
      });

      final response = await _dio.post(
        AppConstants.clockOutEndpoint,
        data: formData,
      );

      if (response.data['success'] == true) {
        if (mounted) {
          _showSuccessSnackBar(response.data['message']);
        }
        await _loadAbsenData();
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Clock out gagal: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const LoadingWidget(message: 'Memuat data absen...')
            : RefreshIndicator(
                onRefresh: _loadAbsenData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Padding(
                        padding: const EdgeInsets.all(
                          AppConstants.paddingMedium,
                        ),
                        child: Column(
                          children: [
                            if (_absenData?['has_jadwal'] == true) ...[
                              _buildTodayStatus(),
                              const SizedBox(height: AppConstants.paddingLarge),
                              _buildAbsenButton(),
                              const SizedBox(height: AppConstants.paddingLarge),
                              _buildScheduleInfo(),
                              const SizedBox(height: AppConstants.paddingLarge),
                              _buildLocationInfo(),
                            ] else ...[
                              _buildNoSchedule(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Absensi Hari Ini',
                        style: AppConstants.titleStyle.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                        style: AppConstants.bodyStyle.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStatus() {
    final absen = _absenData?['absen'];
    final hasClockIn = absen?['clock_in'] != null;
    final hasClockOut = absen?['clock_out'] != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppConstants.primaryColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeCard(
                  'Clock In',
                  hasClockIn ? absen['clock_in'] : '--:--',
                  Icons.login,
                  hasClockIn
                      ? AppConstants.successColor
                      : AppConstants.textSecondaryColor,
                  hasClockIn,
                ),
                const SizedBox(width: 20),
                Container(
                  height: 40,
                  width: 2,
                  color: AppConstants.textSecondaryColor.withOpacity(0.3),
                ),
                const SizedBox(width: 20),
                _buildTimeCard(
                  'Clock Out',
                  hasClockOut ? absen['clock_out'] : '--:--',
                  Icons.logout,
                  hasClockOut
                      ? AppConstants.errorColor
                      : AppConstants.textSecondaryColor,
                  hasClockOut,
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            _buildStatusBadge(absen?['status']),

            if (absen?['work_hours'] != null) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule,
                      color: AppConstants.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total Jam Kerja: ${absen['work_hours']} jam',
                      style: AppConstants.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(
    String label,
    String time,
    IconData icon,
    Color color,
    bool isActive,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              time,
              style: AppConstants.subtitleStyle.copyWith(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppConstants.captionStyle.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    final normalized = (status ?? 'unknown').toLowerCase().trim();
    Color color;
    String text;
    IconData icon;

    switch (normalized) {
      case 'present':
        color = AppConstants.successColor;
        text = 'Hadir';
        icon = Icons.check_circle;
        break;
      case 'late':
        color = AppConstants.warningColor;
        text = 'Terlambat';
        icon = Icons.schedule;
        break;
      case 'absent':
        color = AppConstants.errorColor;
        text = 'Tidak Hadir';
        icon = Icons.cancel;
        break;
      case 'scheduled':
        color = AppConstants.textSecondaryColor;
        text = 'Belum Absen';
        icon = Icons.pending;
        break;
      default:
        color = AppConstants.textSecondaryColor;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenButton() {
    final canClockIn = _absenData?['can_clock_in'] == true;
    final canClockOut = _absenData?['can_clock_out'] == true;

    if (!canClockIn && !canClockOut) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              size: 48,
              color: AppConstants.successColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Absen Hari Ini Sudah Selesai',
              style: AppConstants.subtitleStyle.copyWith(
                color: AppConstants.successColor,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Terima kasih atas kerja keras Anda hari ini!',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (canClockIn) _buildClockInButton(),
        if (canClockOut) _buildClockOutButton(),
      ],
    );
  }

  Widget _buildClockInButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.successColor,
                  AppConstants.successColor.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.successColor.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isProcessing ? null : _clockIn,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing) ...[
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Processing...',
                          style: AppConstants.bodyStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.fingerprint,
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CLOCK IN',
                          style: AppConstants.subtitleStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tap untuk absen masuk',
                          style: AppConstants.captionStyle.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClockOutButton() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.errorColor,
            AppConstants.errorColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.errorColor.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isProcessing ? null : _clockOut,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Processing...',
                    style: AppConstants.bodyStyle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.fingerprint, color: Colors.white, size: 60),
                  const SizedBox(height: 8),
                  Text(
                    'CLOCK OUT',
                    style: AppConstants.subtitleStyle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tap untuk absen keluar',
                    style: AppConstants.captionStyle.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleInfo() {
    final jadwal = _absenData?['jadwal'];
    final shift = jadwal?['shift'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.work,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Informasi Shift', style: AppConstants.subtitleStyle),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),

            _buildInfoRow(Icons.badge, 'Nama Shift', shift?['name'] ?? '-'),
            _buildInfoRow(
              Icons.access_time,
              'Jam Kerja',
              '${shift?['start_time'] ?? '-'} - ${shift?['end_time'] ?? '-'}',
            ),
            if (shift?['break_duration'] != null)
              _buildInfoRow(
                Icons.coffee,
                'Durasi Istirahat',
                '${shift['break_duration']} menit',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: AppConstants.successColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Lokasi Terakhir', style: AppConstants.subtitleStyle),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),

            if (_currentAddress.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  border: Border.all(
                    color: AppConstants.successColor.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  _currentAddress,
                  style: AppConstants.bodyStyle.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 32,
                      color: AppConstants.textSecondaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada data lokasi',
                      style: AppConstants.bodyStyle.copyWith(
                        color: AppConstants.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.textSecondaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: AppConstants.captionStyle),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSchedule() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, AppConstants.backgroundColor],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppConstants.textSecondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy,
                size: 64,
                color: AppConstants.textSecondaryColor,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'Tidak Ada Jadwal Hari Ini',
              style: AppConstants.titleStyle.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Anda tidak memiliki jadwal kerja untuk hari ini. Silakan hubungi admin jika ada kesalahan atau pertanyaan.',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingLarge,
                vertical: AppConstants.paddingMedium,
              ),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nikmati hari libur Anda!',
                    style: AppConstants.bodyStyle.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
