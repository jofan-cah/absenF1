// lib/screens/lembur_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/lembur.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';

class LemburEditScreen extends StatefulWidget {
  final Lembur lembur;

  const LemburEditScreen({Key? key, required this.lembur}) : super(key: key);

  @override
  State<LemburEditScreen> createState() => _LemburEditScreenState();
}

class _LemburEditScreenState extends State<LemburEditScreen> {
  late Dio _dio;
  late StorageService _storage;

  File? _newPhoto;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _newPhoto = File(image.path);
      });
    }
  }

  Future<void> _updateLembur() async {
    if (_newPhoto == null) {
      _showError('Silakan ambil foto bukti terlebih dahulu');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ✅ Debug: cek data sebelum kirim
      print('📋 Data lembur:');
      print('- Tanggal: ${widget.lembur.tanggalLembur}');
      print('- Jam selesai: ${widget.lembur.jamSelesai}');
      print('- Deskripsi: ${widget.lembur.deskripsiPekerjaan}');

      FormData formData = FormData.fromMap({
        'tanggal_lembur': DateFormat(
          'yyyy-MM-dd',
        ).format(widget.lembur.tanggalLembur),
        'jam_selesai': widget.lembur.jamSelesai?.substring(0, 5) ?? '00:00',
        'deskripsi_pekerjaan': widget.lembur.deskripsiPekerjaan ?? '-',
        'bukti_foto': await MultipartFile.fromFile(
          _newPhoto!.path,
          filename: 'lembur_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      // ✅ Debug: print isi FormData
      print('📤 FormData fields:');
      for (var field in formData.fields) {
        print('  ${field.key}: ${field.value}');
      }
      print('📤 FormData files: ${formData.files.length}');

      final response = await _dio.post(
        '/lembur/${widget.lembur.lemburId}/update-photo',
        data: formData,
      );

      if (response.data['success'] == true) {
        _showSuccess('Bukti foto berhasil diupdate');
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } on DioException catch (e) {
      print('❌ Error: ${e.response?.data}');

      String errorMessage = 'Terjadi kesalahan';
      if (e.response?.data is Map) {
        errorMessage = e.response!.data['message'] ?? errorMessage;
      }
      _showError(errorMessage);
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
      appBar: AppBar(title: const Text('Update Bukti Foto'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload bukti foto pekerjaan lembur',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info Lembur
            const Text(
              'Informasi Lembur',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Tanggal',
              DateFormat('dd MMM yyyy').format(widget.lembur.tanggalLembur),
            ),
            _buildInfoRow('Deskripsi', widget.lembur.deskripsiPekerjaan ?? '-'),
            const SizedBox(height: 24),

            // Foto Lama (jika ada)
            if (widget.lembur.buktiFoto != null) ...[
              const Text(
                'Foto Lama',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.lembur.buktiFoto!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Text('Foto lama tidak dapat dimuat'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Foto Baru
            const Text(
              'Foto Baru *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            if (_newPhoto != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _newPhoto!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  // border: Border.all(color: Colors.grey.shade400, style: BorderStyle.dashed),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text('Belum ada foto baru'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: Text(_newPhoto != null ? 'Ganti Foto' : 'Ambil Foto'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _updateLembur,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'UPDATE BUKTI FOTO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
