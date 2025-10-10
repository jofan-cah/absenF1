// lib/screens/lembur_form_screen.dart - DISESUAIKAN DENGAN BACKEND TERBARU
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/lembur.dart';

class LemburFormScreen extends StatefulWidget {
  final Lembur? lembur;

  const LemburFormScreen({super.key, this.lembur});

  @override
  State<LemburFormScreen> createState() => _LemburFormScreenState();
}

class _LemburFormScreenState extends State<LemburFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Dio _dio;
  late StorageService _storage;
  
  final _absenIdController = TextEditingController();
  final _tanggalController = TextEditingController();
  
  // ✅ INPUT JAM MANUAL (24 JAM)
  final _jamMulaiJamController = TextEditingController();
  final _jamMulaiMenitController = TextEditingController();
  final _jamSelesaiJamController = TextEditingController();
  final _jamSelesaiMenitController = TextEditingController();
  
  final _deskripsiController = TextEditingController();
  
  File? _photoFile;
  bool _isSubmitting = false;
  bool _isLoadingAbsen = false;
  String? _absenInfoText;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _storage = await StorageService.getInstance();
    _dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    final token = await _storage.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _dio.options.headers['Accept'] = 'application/json';
    }

    if (widget.lembur != null) {
      // MODE EDIT
      _absenIdController.text = widget.lembur!.absenId ?? '';
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(widget.lembur!.tanggalLembur);
      
      // Parse jam mulai (contoh: "08:30" → jam=08, menit=30)
      final jamMulaiParts = widget.lembur!.jamMulai.split(':');
      _jamMulaiJamController.text = jamMulaiParts[0];
      _jamMulaiMenitController.text = jamMulaiParts[1];
      
      // Parse jam selesai
      final jamSelesaiParts = widget.lembur!.jamSelesai.split(':');
      _jamSelesaiJamController.text = jamSelesaiParts[0];
      _jamSelesaiMenitController.text = jamSelesaiParts[1];
      
      _deskripsiController.text = widget.lembur!.deskripsiPekerjaan;
    } else {
      // MODE CREATE - Auto load absen hari ini
      await _loadTodayAbsen();
    }
  }

  // ✅ AUTO LOAD ABSEN HARI INI
  Future<void> _loadTodayAbsen() async {
    setState(() => _isLoadingAbsen = true);
    
    try {
      final response = await _dio.get(AppConstants.absenTodayEndpoint);
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        
        if (data['has_jadwal'] == true && data['absen'] != null) {
          final absen = data['absen'];
          
          // Cek apakah sudah clock out
          if (absen['clock_out'] != null) {
            setState(() {
              _absenIdController.text = absen['absen_id'];
              _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
              _absenInfoText = '✓ Absen hari ini ditemukan (Clock Out: ${absen['clock_out']})';
            });
          } else {
            setState(() {
              _absenInfoText = '⚠ Anda belum clock out. Silakan clock out terlebih dahulu.';
            });
          }
        } else {
          setState(() {
            _absenInfoText = '⚠ Tidak ada jadwal/absen untuk hari ini';
          });
        }
      }
    } catch (e) {
      setState(() {
        _absenInfoText = '⚠ Gagal memuat data absen: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoadingAbsen = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.lembur?.tanggalLembur ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() => _photoFile = File(image.path));
    }
  }

  // ✅ VALIDASI & SUBMIT
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // VALIDASI: Foto wajib untuk CREATE
    if (widget.lembur == null && _photoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti foto wajib diupload'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Format jam: "HH:mm"
      final jamMulai = '${_jamMulaiJamController.text.padLeft(2, '0')}:${_jamMulaiMenitController.text.padLeft(2, '0')}';
      final jamSelesai = '${_jamSelesaiJamController.text.padLeft(2, '0')}:${_jamSelesaiMenitController.text.padLeft(2, '0')}';
      
      final formData = FormData.fromMap({
        'absen_id': _absenIdController.text,
        'tanggal_lembur': _tanggalController.text,
        'jam_mulai': jamMulai,
        'jam_selesai': jamSelesai,
        'deskripsi_pekerjaan': _deskripsiController.text,
        if (_photoFile != null)
          'bukti_foto': await MultipartFile.fromFile(_photoFile!.path),
      });

      Response response;
      
      if (widget.lembur == null) {
        // CREATE: POST /api/lembur/submit
        response = await _dio.post(
          AppConstants.lemburSubmitEndpoint,
          data: formData,
        );
      } else {
        // UPDATE: PUT /api/lembur/{id}
        response = await _dio.put(
          '${AppConstants.lemburUpdateEndpoint}/${widget.lembur!.lemburId}',
          data: formData,
        );
      }

      if (mounted && response.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lembur == null ? 'Lembur berhasil ditambahkan' : 'Lembur berhasil diupdate'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context, true); // Return true = ada perubahan
      }
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final errorMsg = e.response!.data['message'] ?? 'Gagal menyimpan lembur';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppConstants.errorColor),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppConstants.errorColor),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lembur == null ? 'Tambah Lembur' : 'Edit Lembur'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          children: [
            // ========================================
            // INFO ABSEN
            // ========================================
            if (_isLoadingAbsen)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 12),
                    Text('Memuat data absen hari ini...', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                  ],
                ),
              )
            else if (_absenInfoText != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _absenInfoText!.startsWith('✓') 
                      ? Colors.green.shade50 
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _absenInfoText!.startsWith('✓') 
                        ? Colors.green.shade200 
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _absenInfoText!.startsWith('✓') ? Icons.check_circle_outline : Icons.info_outline,
                      color: _absenInfoText!.startsWith('✓') 
                          ? Colors.green.shade700 
                          : Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _absenInfoText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _absenInfoText!.startsWith('✓') 
                              ? Colors.green.shade700 
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // ========================================
            // ABSEN ID (Required)
            // ========================================
            TextFormField(
              controller: _absenIdController,
              decoration: InputDecoration(
                labelText: 'Absen ID *',
                hintText: widget.lembur == null ? 'Otomatis dari absen hari ini' : 'ID Absen',
                border: const OutlineInputBorder(),
                helperText: 'ID absen dari hari kerja Anda',
                prefixIcon: const Icon(Icons.badge),
                suffixIcon: widget.lembur == null && _absenIdController.text.isEmpty
                    ? IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadTodayAbsen,
                        tooltip: 'Reload absen hari ini',
                      )
                    : null,
              ),
              readOnly: widget.lembur == null && _absenIdController.text.isNotEmpty,
              validator: (v) => v == null || v.isEmpty ? 'Absen ID wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            
            // ========================================
            // TANGGAL (Required)
            // ========================================
            TextFormField(
              controller: _tanggalController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Tanggal Lembur *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
                helperText: 'Pilih tanggal lembur',
              ),
              onTap: _pickDate,
              validator: (v) => v == null || v.isEmpty ? 'Tanggal wajib diisi' : null,
            ),
            const SizedBox(height: 20),
            
            // ========================================
            // JAM MULAI (Required - Input Manual 24 Jam)
            // ========================================
            Text(
              'Jam Mulai Lembur *',
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _jamMulaiJamController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Jam',
                      hintText: '08',
                      border: OutlineInputBorder(),
                      helperText: '00-23',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib';
                      final jam = int.tryParse(v);
                      if (jam == null || jam < 0 || jam > 23) return '0-23';
                      return null;
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _jamMulaiMenitController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Menit',
                      hintText: '30',
                      border: OutlineInputBorder(),
                      helperText: '00-59',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib';
                      final menit = int.tryParse(v);
                      if (menit == null || menit < 0 || menit > 59) return '0-59';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // ========================================
            // JAM SELESAI (Required - Input Manual 24 Jam)
            // ========================================
            Text(
              'Jam Selesai Lembur *',
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _jamSelesaiJamController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Jam',
                      hintText: '17',
                      border: OutlineInputBorder(),
                      helperText: '00-23',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib';
                      final jam = int.tryParse(v);
                      if (jam == null || jam < 0 || jam > 23) return '0-23';
                      return null;
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _jamSelesaiMenitController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Menit',
                      hintText: '00',
                      border: OutlineInputBorder(),
                      helperText: '00-59',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib';
                      final menit = int.tryParse(v);
                      if (menit == null || menit < 0 || menit > 59) return '0-59';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // ========================================
            // DESKRIPSI (Required, max 500 chars)
            // ========================================
            TextFormField(
              controller: _deskripsiController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Pekerjaan *',
                hintText: 'Jelaskan detail pekerjaan lembur yang dilakukan',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.description),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Deskripsi wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            
            // ========================================
            // BUKTI FOTO (Required untuk CREATE)
            // ========================================
            if (_photoFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _photoFile!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            ElevatedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _photoFile == null 
                    ? (widget.lembur == null ? 'Ambil Foto Bukti *' : 'Ganti Foto (Opsional)') 
                    : 'Ganti Foto'
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: _photoFile == null && widget.lembur == null
                    ? AppConstants.primaryColor 
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.lembur == null)
              Text(
                '* Foto wajib untuk pengajuan baru',
                style: AppConstants.captionStyle.copyWith(
                  color: AppConstants.errorColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 24),
            
            // ========================================
            // SUBMIT BUTTON
            // ========================================
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(18),
                backgroundColor: AppConstants.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.lembur == null ? Icons.save : Icons.update,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.lembur == null ? 'Simpan Lembur' : 'Update Lembur',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              '* Field bertanda bintang wajib diisi',
              textAlign: TextAlign.center,
              style: AppConstants.captionStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _absenIdController.dispose();
    _tanggalController.dispose();
    _jamMulaiJamController.dispose();
    _jamMulaiMenitController.dispose();
    _jamSelesaiJamController.dispose();
    _jamSelesaiMenitController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }
}