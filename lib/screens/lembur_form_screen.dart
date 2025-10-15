// lib/screens/lembur_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/lembur.dart';
import '../models/absen.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/loading_widget.dart';

class LemburFormScreen extends StatefulWidget {
  final Lembur? lembur; // null = create, ada data = update

  const LemburFormScreen({Key? key, this.lembur}) : super(key: key);

  @override
  State<LemburFormScreen> createState() => _LemburFormScreenState();
}

class _LemburFormScreenState extends State<LemburFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Dio _dio;
  late StorageService _storage;
  
  // Controllers
  final _tanggalController = TextEditingController();
  final _jamMulaiController = TextEditingController();
  final _jamSelesaiController = TextEditingController();
  final _deskripsiController = TextEditingController();
  
  // State
  bool _isSubmitting = false;
  bool _isLoadingAbsen = true;
  List<Absen> _absenList = [];
  String? _selectedAbsenId;
  File? _photoFile;
  String? _existingPhotoUrl;
  
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
    
    _initForm();
    _loadAbsenList();
  }

  void _initForm() {
    if (widget.lembur != null) {
      // MODE UPDATE - populate existing data
      final lembur = widget.lembur!;
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(lembur.tanggalLembur);
      _jamMulaiController.text = lembur.jamMulai;
      _jamSelesaiController.text = lembur.jamSelesai;
      _deskripsiController.text = lembur.deskripsiPekerjaan;
      _selectedAbsenId = lembur.absenId;
      _existingPhotoUrl = lembur.buktiFoto;
    }
  }

  Future<void> _loadAbsenList() async {
    setState(() => _isLoadingAbsen = true);
    
    try {
      // Load absen yang sudah clock_out (syarat untuk lembur)
      final response = await _dio.get(
        AppConstants.absenHistoryEndpoint,
        queryParameters: {
          'has_clock_out': true,
          'month': DateTime.now().month,
          'year': DateTime.now().year,
        },
      );

      if (response.data['success']) {
        final List<dynamic> data = response.data['data']['data'];
        setState(() {
          _absenList = data.map((json) => Absen.fromJson(json)).toList();
        });
      }
    } catch (e) {
      _showError('Gagal memuat data absen: ${e.toString()}');
    } finally {
      setState(() => _isLoadingAbsen = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _photoFile = File(pickedFile.path);
        _existingPhotoUrl = null; // Clear existing photo
      });
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formattedTime;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi foto untuk create
    if (widget.lembur == null && _photoFile == null) {
      _showError('Bukti foto wajib diupload');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formData = FormData.fromMap({
        if (widget.lembur == null) 'absen_id': _selectedAbsenId,
        'tanggal_lembur': _tanggalController.text,
        'jam_mulai': _jamMulaiController.text,
        'jam_selesai': _jamSelesaiController.text,
        'deskripsi_pekerjaan': _deskripsiController.text,
        if (_photoFile != null)
          'bukti_foto': await MultipartFile.fromFile(_photoFile!.path),
      });

      final String url;

      if (widget.lembur == null) {
        // CREATE MODE
        url = AppConstants.lemburSubmitEndpoint;
      } else {
        // UPDATE MODE
        url = '${AppConstants.lemburUpdateEndpoint}/${widget.lembur!.lemburId}';
        // Untuk PUT dengan file, gunakan _method override
        formData.fields.add(const MapEntry('_method', 'PUT'));
      }

      final response = await _dio.post(url, data: formData);

      if (response.data['success']) {
        if (mounted) {
          _showSuccess(widget.lembur == null 
            ? 'Lembur berhasil dibuat. Silakan submit untuk disetujui.'
            : 'Lembur berhasil diupdate'
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'Terjadi kesalahan';
      
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('message')) {
          errorMessage = data['message'];
        } else if (data is Map && data.containsKey('errors')) {
          final errors = data['errors'] as Map;
          errorMessage = errors.values.first.toString();
        }
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
        title: Text(widget.lembur == null ? 'Tambah Lembur' : 'Edit Lembur'),
        elevation: 0,
      ),
      body: _isLoadingAbsen
          ? const LoadingWidget(message: 'Memuat data...')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
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
                              'Informasi Penting',
                              style: AppConstants.subtitleStyle.copyWith(
                                fontSize: 14,
                                color: AppConstants.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Lembur hanya bisa diajukan max 1 jam setelah shift berakhir\n'
                          '• Anda harus sudah clock out terlebih dahulu\n'
                          '• Total jam dihitung otomatis oleh sistem\n'
                          '• Tunjangan: 0-3.99 jam = 1x, 4+ jam = 2x uang makan',
                          style: AppConstants.captionStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Absen Selector (hanya untuk create)
                  if (widget.lembur == null) ...[
                    Text('Pilih Absensi *', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedAbsenId,
                      decoration: InputDecoration(
                        hintText: 'Pilih tanggal absensi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                        filled: true,
                        fillColor: AppConstants.cardColor,
                      ),
                      items: _absenList.map((absen) {
                        return DropdownMenuItem(
                          value: absen.absenId,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(absen.date),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Clock Out: ${absen.clockOut ?? "-"}',
                                style: AppConstants.captionStyle,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedAbsenId = value);
                        
                        if (value != null) {
                          final selectedAbsen = _absenList.firstWhere((a) => a.absenId == value);
                          _tanggalController.text = DateFormat('yyyy-MM-dd').format(selectedAbsen.date);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Pilih absensi terlebih dahulu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tanggal Lembur
                  Text('Tanggal Lembur *', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tanggalController,
                    decoration: InputDecoration(
                      hintText: 'Pilih tanggal',
                      suffixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      filled: true,
                      fillColor: AppConstants.cardColor,
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        _tanggalController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Tanggal wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Jam Mulai & Jam Selesai
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Mulai *', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _jamMulaiController,
                              decoration: InputDecoration(
                                hintText: 'HH:mm',
                                suffixIcon: const Icon(Icons.access_time),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                ),
                                filled: true,
                                fillColor: AppConstants.cardColor,
                              ),
                              readOnly: true,
                              onTap: () => _selectTime(_jamMulaiController),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Selesai *', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _jamSelesaiController,
                              decoration: InputDecoration(
                                hintText: 'HH:mm',
                                suffixIcon: const Icon(Icons.access_time),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                ),
                                filled: true,
                                fillColor: AppConstants.cardColor,
                              ),
                              readOnly: true,
                              onTap: () => _selectTime(_jamSelesaiController),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Deskripsi Pekerjaan
                  Text('Deskripsi Pekerjaan *', style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _deskripsiController,
                    decoration: InputDecoration(
                      hintText: 'Jelaskan pekerjaan yang dikerjakan saat lembur',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      filled: true,
                      fillColor: AppConstants.cardColor,
                    ),
                    maxLines: 4,
                    maxLength: 500,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Deskripsi wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Bukti Foto
                  Text(
                    'Bukti Foto ${widget.lembur == null ? "*" : "(Opsional)"}',
                    style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        color: AppConstants.cardColor,
                      ),
                      child: _photoFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              child: Image.file(_photoFile!, fit: BoxFit.cover),
                            )
                          : _existingPhotoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                  child: Image.network(
                                    '${AppConstants.baseUrl.replaceAll('/api', '')}/storage/$_existingPhotoUrl',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildPlaceholder();
                                    },
                                  ),
                                )
                              : _buildPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.lembur == null ? 'SIMPAN DRAFT' : 'UPDATE LEMBUR',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 64, color: AppConstants.textSecondaryColor),
        const SizedBox(height: 8),
        Text(
          'Tap untuk ambil foto',
          style: AppConstants.captionStyle,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _jamMulaiController.dispose();
    _jamSelesaiController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }
}