// lib/screens/lembur_finish_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/lembur.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/loading_widget.dart';

class LemburFinishScreen extends StatefulWidget {
  final Lembur lembur;

  const LemburFinishScreen({Key? key, required this.lembur}) : super(key: key);

  @override
  State<LemburFinishScreen> createState() => _LemburFinishScreenState();
}

class _LemburFinishScreenState extends State<LemburFinishScreen> {
  late Dio _dio;
  late StorageService _storage;

  final _formKey = GlobalKey<FormState>();
  final _deskripsiController = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;

  // ✅ Jam selesai otomatis dari sistem
  late String _jamSelesai;
  late DateTime _completedAt;

  @override
  void initState() {
    super.initState();
    // ✅ Set jam selesai saat screen dibuka (tanpa detik)
    _completedAt = DateTime.now();
    _jamSelesai = DateFormat('HH:mm').format(_completedAt); // ← UBAH INI
    _initServices();
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
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _finishLembur() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      _showError('Silakan ambil foto bukti lembur');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      print('🏁 === FINISHING LEMBUR ===');

      // ✅ Update jam selesai ke waktu sekarang (saat klik button)
      final now = DateTime.now();

      // ✅ FIX: Format tanpa detik (H:i) sesuai validasi backend
      _jamSelesai = DateFormat('HH:mm').format(now); // ← UBAH INI (hapus :ss)
      _completedAt = now;

      print('📋 Lembur ID: ${widget.lembur.lemburId}');
      print('📋 Jam Mulai: ${widget.lembur.jamMulai}');
      print('📋 Jam Selesai: $_jamSelesai (jam sekarang)');
      print('📋 Completed At: ${_completedAt.toIso8601String()}');

      // Hitung total jam
      final startedAt = widget.lembur.startedAt;
      double totalJam = 0;
      if (startedAt != null) {
        final duration = now.difference(startedAt.toLocal());
        totalJam = duration.inMinutes / 60.0;
        print('📋 Total Jam (dihitung): ${totalJam.toStringAsFixed(2)} jam');
      }

      // Prepare form data
      final formData = FormData.fromMap({
        'jam_selesai': _jamSelesai, // ✅ Format: HH:mm (tanpa detik)
        'completed_at': _completedAt.toIso8601String(),
        'total_jam': totalJam.toStringAsFixed(2),
        'deskripsi_pekerjaan': _deskripsiController.text.trim(),
        'bukti_foto': await MultipartFile.fromFile(
          _selectedImage!.path,
          filename:
              'lembur_${widget.lembur.lemburId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _dio.post(
        '/lembur/${widget.lembur.lemburId}/finish',
        data: formData,
      );

      print('📦 Response: ${response.data}');

      if (response.data['success']) {
        _showSuccess('Lembur berhasil diselesaikan');
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showError(response.data['message'] ?? 'Gagal menyelesaikan lembur');
      }
    } on DioException catch (e) {
      print('❌ DIO EXCEPTION: ${e.type}');
      print('📦 Response: ${e.response?.data}');

      String errorMessage = 'Terjadi kesalahan';

      if (e.response?.data is Map && e.response!.data.containsKey('message')) {
        errorMessage = e.response!.data['message'];

        // ✅ Tampilkan detail error validasi
        if (e.response!.data.containsKey('errors')) {
          final errors = e.response!.data['errors'] as Map;
          final errorDetails = errors.values
              .map((e) => e.toString())
              .join(', ');
          errorMessage = '$errorMessage: $errorDetails';
        }
      }

      _showError(errorMessage);
    } catch (e) {
      print('❌ ERROR: $e');
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
    // ✅ Hitung durasi real-time
    final duration = widget.lembur.startedAt != null
        ? DateTime.now().difference(widget.lembur.startedAt!.toLocal())
        : Duration.zero;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: const Text('Selesai Lembur'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        Icon(
                          Icons.info_outline,
                          color: AppConstants.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Informasi Lembur',
                          style: AppConstants.subtitleStyle.copyWith(
                            color: AppConstants.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(
                      'Tanggal',
                      DateFormat(
                        'dd MMM yyyy',
                        'id_ID',
                      ).format(widget.lembur.tanggalLembur),
                    ),
                    _buildInfoRow(
                      'Jam Mulai',
                      widget.lembur.startedAt != null
                          ? DateFormat(
                              'HH:mm',
                            ).format(widget.lembur.startedAt!.toLocal())
                          : widget.lembur.jamMulai,
                    ),
                    _buildInfoRow(
                      'Jam Selesai',
                      _jamSelesai,
                    ), // ✅ Tampilkan jam sekarang
                    _buildInfoRow('Durasi', '${hours}h ${minutes}m'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Deskripsi Pekerjaan
              Text('Deskripsi Pekerjaan *', style: AppConstants.subtitleStyle),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deskripsiController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Jelaskan pekerjaan yang dilakukan saat lembur...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusLarge,
                    ),
                  ),
                  filled: true,
                  fillColor: AppConstants.cardColor,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Deskripsi pekerjaan wajib diisi';
                  }
                  if (value.trim().length < 10) {
                    return 'Deskripsi minimal 10 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Foto Bukti
              Text('Foto Bukti *', style: AppConstants.subtitleStyle),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppConstants.cardColor,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusLarge,
                    ),
                    border: Border.all(
                      color: AppConstants.primaryColor.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLarge,
                          ),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 48,
                              color: AppConstants.textSecondaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap untuk ambil foto',
                              style: AppConstants.bodyStyle.copyWith(
                                color: AppConstants.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _finishLembur,
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle, size: 28),
                  label: Text(
                    _isSubmitting ? 'MENYIMPAN...' : 'SELESAI LEMBUR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.successColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          Text(
            value,
            style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _deskripsiController.dispose();
    super.dispose();
  }
}
