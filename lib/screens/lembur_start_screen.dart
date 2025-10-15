// lib/screens/lembur_start_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/absen.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/loading_widget.dart';

class LemburStartScreen extends StatefulWidget {
  const LemburStartScreen({Key? key}) : super(key: key);

  @override
  State<LemburStartScreen> createState() => _LemburStartScreenState();
}

class _LemburStartScreenState extends State<LemburStartScreen> {
  late Dio _dio;
  late StorageService _storage;
  
  bool _isLoadingAbsen = true;
  bool _isSubmitting = false;
  Absen? _todayAbsen;
  Map<String, dynamic>? _formInfo;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _storage = await StorageService.getInstance();
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
    ));
    
    final token = await _storage.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _dio.options.headers['Accept'] = 'application/json';
    }
    
    await _loadTodayAbsen();
  }

  Future<void> _loadTodayAbsen() async {
    setState(() => _isLoadingAbsen = true);
    
    try {
      print('🔍 === LOADING TODAY ABSEN ===');
      
      final response = await _dio.get('/absen/today');
      
      print('📦 Response: ${response.data}');

      if (response.data['success']) {
        final data = response.data['data'];
        
        // Cek apakah ada jadwal
        if (data['has_jadwal'] != true) {
          print('⚠️ Tidak ada jadwal hari ini');
          setState(() => _todayAbsen = null);
          return;
        }
        
        // Cek apakah ada absen
        if (data['absen'] == null) {
          print('⚠️ Belum melakukan absensi hari ini');
          setState(() => _todayAbsen = null);
          return;
        }
        
        final absenJson = data['absen'];
        
        // Cek apakah sudah clock out
        if (absenJson['clock_out'] == null) {
          print('⚠️ Belum clock out');
          setState(() => _todayAbsen = null);
          return;
        }
        
        print('✅ Found today absen with clock out');
        
        // Parse ke model Absen
        final absen = Absen.fromJson(absenJson);
        
        setState(() => _todayAbsen = absen);
        
        // Auto load form info
        await _loadFormInfo(absen.absenId);
        
      } else {
        _showError(response.data['message'] ?? 'Gagal memuat data absen');
      }
    } catch (e) {
      print('❌ ERROR: $e');
      _showError('Gagal memuat data absen');
    } finally {
      setState(() => _isLoadingAbsen = false);
    }
  }

  Future<void> _loadFormInfo(String absenId) async {
    try {
      print('🔍 Loading form info for: $absenId');
      
      final response = await _dio.get('/lembur/form-info/$absenId');
      
      if (response.data['success']) {
        final formData = response.data['data'];
        
        if (formData is Map<String, dynamic>) {
          setState(() {
            _formInfo = Map<String, dynamic>.from(formData);
          });
          print('✅ Form info loaded');
        }
      }
    } catch (e) {
      print('❌ ERROR loading form info: $e');
      _showError('Gagal memuat info lembur');
    }
  }

  Future<void> _startLembur() async {
    if (_todayAbsen == null) {
      _showError('Tidak ada absensi hari ini');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      print('🚀 Starting lembur for: ${_todayAbsen!.absenId}');
      
      final response = await _dio.post(
        '/lembur/start',
        data: {
          'absen_id': _todayAbsen!.absenId,
          'jam_selesai': '00:00:00',
          'deskripsi_pekerjaan': '-',
        },
      );

      if (response.data['success']) {
        _showSuccess('Lembur berhasil dimulai');
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'Terjadi kesalahan';
      
      if (e.response?.data is Map && e.response!.data.containsKey('message')) {
        errorMessage = e.response!.data['message'];
      }
      
      _showError(errorMessage);
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppConstants.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Mulai Lembur'),
        elevation: 0,
      ),
      body: _isLoadingAbsen
          ? const LoadingWidget(message: 'Memuat data...')
          : _todayAbsen == null
              ? _buildNoAbsenView()
              : _buildStartLemburView(),
    );
  }

  Widget _buildStartLemburView() {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      children: [
        // Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppConstants.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Konsep Lembur Baru',
                    style: AppConstants.subtitleStyle.copyWith(
                      fontSize: 16,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '1. MULAI LEMBUR - klik tombol ini untuk memulai\n'
                '2. SELESAI LEMBUR - setelah pekerjaan selesai, input jam selesai & foto\n'
                '3. SUBMIT - ajukan ke koordinator untuk approval\n\n'
                '⏰ Lembur harus dimulai max 1 jam setelah shift berakhir\n'
                '📸 Foto & deskripsi diinput saat finish',
                style: AppConstants.bodyStyle.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Absensi Hari Ini Card
        _buildTodayAbsenCard(),
        const SizedBox(height: 24),

        // Form Info
        if (_formInfo != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_formInfo!['can_create_lembur'] == true 
                  ? AppConstants.successColor 
                  : AppConstants.errorColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: (_formInfo!['can_create_lembur'] == true 
                    ? AppConstants.successColor 
                    : AppConstants.errorColor).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _formInfo!['can_create_lembur'] == true 
                          ? Icons.check_circle 
                          : Icons.warning,
                      color: _formInfo!['can_create_lembur'] == true 
                          ? AppConstants.successColor 
                          : AppConstants.errorColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Informasi Shift',
                      style: AppConstants.subtitleStyle.copyWith(
                        color: _formInfo!['can_create_lembur'] == true 
                            ? AppConstants.successColor 
                            : AppConstants.errorColor,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildInfoRow('Shift', _formInfo!['shift_name']?.toString() ?? '-'),
                _buildInfoRow('Jam Shift', '${_formInfo!['shift_start'] ?? '-'} - ${_formInfo!['shift_end'] ?? '-'}'),
                _buildInfoRow('Jam Mulai Lembur', _formInfo!['jam_mulai_lembur']?.toString() ?? '-'),
                if (_formInfo!['max_start_datetime'] != null)
                  _buildInfoRow('Batas Mulai', DateFormat('dd/MM/yyyy HH:mm').format(
                    DateTime.parse(_formInfo!['max_start_datetime'])
                  )),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_formInfo!['can_create_lembur'] == true 
                        ? AppConstants.successColor 
                        : AppConstants.errorColor).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formInfo!['info_message']?.toString() ?? '',
                    style: AppConstants.captionStyle.copyWith(
                      color: _formInfo!['can_create_lembur'] == true 
                          ? AppConstants.successColor 
                          : AppConstants.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Start Button
        SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSubmitting || _formInfo == null || _formInfo!['can_create_lembur'] != true)
                ? null
                : _startLembur,
            icon: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 28),
            label: Text(
              _isSubmitting ? 'MEMULAI...' : 'MULAI LEMBUR SEKARANG',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.successColor,
              disabledBackgroundColor: AppConstants.textSecondaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayAbsenCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  Icons.calendar_today,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Absensi Hari Ini', style: AppConstants.subtitleStyle),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_todayAbsen!.date),
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Clock In', _todayAbsen!.clockIn ?? '-'),
          _buildInfoRow('Clock Out', _todayAbsen!.clockOut ?? '-'),
        ],
      ),
    );
  }

  Widget _buildNoAbsenView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppConstants.textSecondaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy,
                size: 80,
                color: AppConstants.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tidak Bisa Mulai Lembur',
              style: AppConstants.subtitleStyle.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Kemungkinan penyebab:\n\n'
              '• Belum melakukan clock out hari ini\n'
              '• Belum ada jadwal shift hari ini\n'
              '• Sudah melewati batas waktu mulai lembur\n\n'
              'Silakan hubungi admin jika ada kendala.',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppConstants.captionStyle),
          Flexible(
            child: Text(
              value,
              style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}