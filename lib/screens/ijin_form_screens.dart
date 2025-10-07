// lib/screens/ijin_form_screens.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // ✅ TAMBAH
import 'package:image_picker/image_picker.dart'; // ✅ TAMBAH
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/ijin.dart';

// ========================================
// 1. FORM IJIN REGULER (Sakit, Cuti, Pribadi)
// ========================================
class IjinFormScreen extends StatefulWidget {
  final IjinType ijinType;

  const IjinFormScreen({super.key, required this.ijinType});

  @override
  State<IjinFormScreen> createState() => _IjinFormScreenState();
}

class _IjinFormScreenState extends State<IjinFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Dio _dio;
  late StorageService _storage;

  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  final _reasonController = TextEditingController();

  DateTime? _dateFrom;
  DateTime? _dateTo;
  File? _photoFile; // ✅ TAMBAH untuk menyimpan file foto
  bool _isSubmitting = false;

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
  }

  Future<void> _selectDateFrom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dateFrom = date;
        _dateFromController.text = DateFormat('yyyy-MM-dd').format(date);
        
        // Reset dateTo jika dateFrom berubah
        if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
          _dateTo = null;
          _dateToController.clear();
        }
      });
    }
  }

  Future<void> _selectDateTo() async {
    if (_dateFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai terlebih dahulu')),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _dateFrom!,
      firstDate: _dateFrom!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dateTo = date;
        _dateToController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  // ✅ TAMBAH FUNGSI UNTUK AMBIL FOTO
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _photoFile = File(image.path));
    }
  }

  // ✅ TAMBAH FUNGSI UNTUK PILIH DARI GALERI
  Future<void> _pickPhotoFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() => _photoFile = File(image.path));
    }
  }

  // ✅ TAMBAH DIALOG PILIHAN FOTO
  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotoFromGallery();
              },
            ),
            if (_photoFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photoFile = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // ✅ GUNAKAN FormData untuk upload file
      final formData = FormData.fromMap({
        'ijin_type_id': widget.ijinType.ijinTypeId,
        'date_from': _dateFromController.text,
        'date_to': _dateToController.text,
        'reason': _reasonController.text,
      });

      // ✅ TAMBAH FOTO JIKA ADA
      if (_photoFile != null) {
        formData.files.add(
          MapEntry(
            'photo',
            await MultipartFile.fromFile(
              _photoFile!.path,
              filename: 'ijin_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
      }

      final response = await _dio.post(
        AppConstants.ijinSubmitEndpoint,
        data: formData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['message'] ?? 'Pengajuan ijin berhasil'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Gagal mengajukan ijin';
        if (e is DioException && e.response?.data != null) {
          errorMsg = e.response!.data['message'] ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppConstants.errorColor,
          ),
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
        title: Text('Ajukan ${widget.ijinType.name}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: AppConstants.primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppConstants.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.ijinType.description ?? 
                        'Isi form di bawah untuk mengajukan ${widget.ijinType.name}',
                        style: AppConstants.captionStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tanggal Mulai
            TextFormField(
              controller: _dateFromController,
              decoration: const InputDecoration(
                labelText: 'Tanggal Mulai',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _selectDateFrom,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Tanggal Selesai
            TextFormField(
              controller: _dateToController,
              decoration: const InputDecoration(
                labelText: 'Tanggal Selesai',
                prefixIcon: Icon(Icons.event),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _selectDateTo,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Total Hari
            if (_dateFrom != null && _dateTo != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppConstants.successColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppConstants.successColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${_dateTo!.difference(_dateFrom!).inDays + 1} hari',
                      style: TextStyle(
                        color: AppConstants.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Alasan
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // ✅ TAMBAH SECTION FOTO
            Text(
              'Foto Pendukung (Opsional)',
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Preview Foto atau Tombol Upload
            if (_photoFile != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _photoFile!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.red,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => setState(() => _photoFile = null),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showPhotoOptions,
                icon: const Icon(Icons.edit),
                label: const Text('Ganti Foto'),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _showPhotoOptions,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Tambah Foto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : const Text('Ajukan Ijin'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}

// ========================================
// 2. FORM TUKAR SHIFT
// ========================================
class ShiftSwapFormScreen extends StatefulWidget {
  final IjinType ijinType;

  const ShiftSwapFormScreen({super.key, required this.ijinType});

  @override
  State<ShiftSwapFormScreen> createState() => _ShiftSwapFormScreenState();
}

class _ShiftSwapFormScreenState extends State<ShiftSwapFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Dio _dio;
  late StorageService _storage;

  final _originalDateController = TextEditingController();
  final _replacementDateController = TextEditingController();
  final _reasonController = TextEditingController();

  DateTime? _originalDate;
  DateTime? _replacementDate;
  bool _isSubmitting = false;

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
  }

  Future<void> _selectOriginalDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Hanya Minggu (dayOfWeek = 7)
        return date.weekday == DateTime.sunday;
      },
    );

    if (date != null) {
      setState(() {
        _originalDate = date;
        _originalDateController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  Future<void> _selectReplacementDate() async {
    if (_originalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal asli terlebih dahulu')),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _originalDate!.add(const Duration(days: 1)),
      firstDate: _originalDate!.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Tidak boleh Minggu
        return date.weekday != DateTime.sunday;
      },
    );

    if (date != null) {
      setState(() {
        _replacementDate = date;
        _replacementDateController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await _dio.post(
        AppConstants.ijinShiftSwapEndpoint,
        data: {
          'original_shift_date': _originalDateController.text,
          'replacement_shift_date': _replacementDateController.text,
          'reason': _reasonController.text,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['message'] ?? 'Pengajuan tukar shift berhasil'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Gagal mengajukan tukar shift';
        if (e is DioException && e.response?.data != null) {
          errorMsg = e.response!.data['message'] ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppConstants.errorColor,
          ),
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
        title: const Text('Tukar Shift'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: AppConstants.warningColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppConstants.warningColor),
                        const SizedBox(width: 12),
                        Text(
                          'Ketentuan Tukar Shift',
                          style: AppConstants.subtitleStyle.copyWith(
                            color: AppConstants.warningColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Tanggal asli harus hari Minggu (piket)\n'
                      '• Tanggal pengganti tidak boleh hari Minggu\n'
                      '• Tanggal pengganti harus setelah tanggal asli',
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tanggal Asli (Minggu)
            TextFormField(
              controller: _originalDateController,
              decoration: const InputDecoration(
                labelText: 'Tanggal Piket Asli (Minggu)',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
                helperText: 'Pilih tanggal Minggu yang ingin ditukar',
              ),
              readOnly: true,
              onTap: _selectOriginalDate,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Tanggal Pengganti
            TextFormField(
              controller: _replacementDateController,
              decoration: const InputDecoration(
                labelText: 'Tanggal Pengganti',
                prefixIcon: Icon(Icons.event),
                border: OutlineInputBorder(),
                helperText: 'Pilih tanggal pengganti (bukan Minggu)',
              ),
              readOnly: true,
              onTap: _selectReplacementDate,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Alasan
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : const Text('Ajukan Tukar Shift'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _originalDateController.dispose();
    _replacementDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}

// ========================================
// 3. FORM CUTI PENGGANTI
// ========================================
class CompensationLeaveFormScreen extends StatefulWidget {
  final IjinType ijinType;

  const CompensationLeaveFormScreen({super.key, required this.ijinType});

  @override
  State<CompensationLeaveFormScreen> createState() =>
      _CompensationLeaveFormScreenState();
}

class _CompensationLeaveFormScreenState
    extends State<CompensationLeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late Dio _dio;
  late StorageService _storage;

  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  final _reasonController = TextEditingController();

  List<Map<String, dynamic>> _availablePiketDates = [];
  String? _selectedPiketDate;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = true;
  bool _isSubmitting = false;

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

    await _loadAvailablePiketDates();
  }

  Future<void> _loadAvailablePiketDates() async {
    try {
      final response = await _dio.get(AppConstants.ijinAvailablePiketDatesEndpoint);

      if (response.data['success'] == true) {
        setState(() {
          _availablePiketDates =
              List<Map<String, dynamic>>.from(response.data['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat data piket'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectDateFrom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Tidak boleh Minggu
        return date.weekday != DateTime.sunday;
      },
    );

    if (date != null) {
      setState(() {
        _dateFrom = date;
        _dateFromController.text = DateFormat('yyyy-MM-dd').format(date);
        
        if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
          _dateTo = null;
          _dateToController.clear();
        }
      });
    }
  }

  Future<void> _selectDateTo() async {
    if (_dateFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai terlebih dahulu')),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _dateFrom!,
      firstDate: _dateFrom!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Tidak boleh Minggu
        return date.weekday != DateTime.sunday;
      },
    );

    if (date != null) {
      setState(() {
        _dateTo = date;
        _dateToController.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedPiketDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal piket terlebih dahulu')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await _dio.post(
        AppConstants.ijinCompensationLeaveEndpoint,
        data: {
          'original_shift_date': _selectedPiketDate,
          'date_from': _dateFromController.text,
          'date_to': _dateToController.text,
          'reason': _reasonController.text,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['message'] ?? 'Pengajuan cuti pengganti berhasil'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Gagal mengajukan cuti pengganti';
        if (e is DioException && e.response?.data != null) {
          errorMsg = e.response!.data['message'] ?? errorMsg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuti Pengganti')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_availablePiketDates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuti Pengganti')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy,
                    size: 64, color: AppConstants.textSecondaryColor),
                const SizedBox(height: 16),
                Text(
                  'Tidak Ada Piket yang Tersedia',
                  style: AppConstants.subtitleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Anda belum memiliki piket hari Minggu yang bisa diklaim untuk cuti pengganti.',
                  style: AppConstants.bodyStyle.copyWith(
                    color: AppConstants.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuti Pengganti'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Card(
              color: Colors.purple.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.purple),
                        const SizedBox(width: 12),
                        Text(
                          'Ketentuan Cuti Pengganti',
                          style: AppConstants.subtitleStyle.copyWith(
                            color: Colors.purple,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Pilih tanggal piket yang sudah Anda kerjakan\n'
                      '• Tanggal cuti tidak boleh hari Minggu\n'
                      '• Tanggal cuti harus setelah hari ini',
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pilih Tanggal Piket
            DropdownButtonFormField<String>(
              value: _selectedPiketDate,
              decoration: const InputDecoration(
                labelText: 'Pilih Tanggal Piket',
                prefixIcon: Icon(Icons.event_available),
                border: OutlineInputBorder(),
                helperText: 'Piket hari Minggu yang sudah dikerjakan',
              ),
              items: _availablePiketDates.map((piket) {
                return DropdownMenuItem<String>(
                  value: piket['date'],
                  child: Text(piket['formatted_date']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPiketDate = value);
              },
              validator: (v) => v == null ? 'Wajib dipilih' : null,
            ),
            const SizedBox(height: 16),

            // Tanggal Mulai Cuti
            TextFormField(
              controller: _dateFromController,
              decoration: const InputDecoration(
                labelText: 'Tanggal Mulai Cuti',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _selectDateFrom,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Tanggal Selesai Cuti
            TextFormField(
              controller: _dateToController,
              decoration: const InputDecoration(
                labelText: 'Tanggal Selesai Cuti',
                prefixIcon: Icon(Icons.event),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: _selectDateTo,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Total Hari
            if (_dateFrom != null && _dateTo != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${_dateTo!.difference(_dateFrom!).inDays + 1} hari',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Alasan (Opsional)
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan (Opsional)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : const Text('Ajukan Cuti Pengganti'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}