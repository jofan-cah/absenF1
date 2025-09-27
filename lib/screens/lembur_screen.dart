// lib/screens/lembur_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/lembur.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';

class LemburScreen extends StatefulWidget {
  const LemburScreen({super.key});

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen> with SingleTickerProviderStateMixin {
  late StorageService _storage;
  late Dio _dio;
  late TabController _tabController;
  
  List<Lembur> _lemburList = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    
    await _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadLemburList(),
      _loadSummary(),
    ]);
  }

  Future<void> _loadLemburList() async {
    try {
      final response = await _dio.get(
        AppConstants.lemburMyListEndpoint,
        queryParameters: {
          'month': _selectedMonth,
          'year': _selectedYear,
          if (_selectedStatus != null) 'status': _selectedStatus,
          'per_page': 50,
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _lemburList = (response.data['data'] as List)
              .map((json) => Lembur.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Gagal memuat data lembur: ${e.toString()}');
    }
  }

  Future<void> _loadSummary() async {
    try {
      final response = await _dio.get(
        AppConstants.lemburSummaryEndpoint,
        queryParameters: {
          'month': _selectedMonth,
          'year': _selectedYear,
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _summary = response.data['data']['summary'];
        });
      }
    } catch (e) {
      // Silent error, summary is optional
    }
  }

  Future<void> _submitLembur(Lembur lembur) async {
    try {
      final response = await _dio.post(
        '${AppConstants.lemburDetailEndpoint}/${lembur.lemburId}/submit',
      );
      
      if (response.data['success'] == true) {
        _showSuccess('Lembur berhasil diajukan');
        await _loadData();
      }
    } catch (e) {
      _showError('Gagal mengajukan lembur: ${e.toString()}');
    }
  }

  Future<void> _deleteLembur(Lembur lembur) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Hapus lembur ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.delete('${AppConstants.lemburDeleteEndpoint}/${lembur.lemburId}');
        _showSuccess('Lembur berhasil dihapus');
        await _loadData();
      } catch (e) {
        _showError('Gagal menghapus lembur: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppConstants.errorColor),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppConstants.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Lembur'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daftar Lembur'),
            Tab(text: 'Summary'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLemburList(),
          _buildSummary(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Lembur'),
      ),
    );
  }

  Widget _buildLemburList() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Memuat data lembur...');
    }

    if (_lemburList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: AppConstants.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              'Belum ada data lembur',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: _lemburList.length,
        itemBuilder: (context, index) {
          final lembur = _lemburList[index];
          return _buildLemburCard(lembur);
        },
      ),
    );
  }

  Widget _buildLemburCard(Lembur lembur) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      onTap: () => _showLemburDetail(lembur),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(lembur.tanggalLembur),
                      style: AppConstants.subtitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lembur.jamMulai} - ${lembur.jamSelesai}',
                      style: AppConstants.bodyStyle,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(lembur.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: AppConstants.textSecondaryColor),
              const SizedBox(width: 4),
              Text(
                '${lembur.totalJam.toStringAsFixed(1)} jam',
                style: AppConstants.captionStyle,
              ),
              const SizedBox(width: 16),
              Icon(Icons.tag, size: 16, color: AppConstants.textSecondaryColor),
              const SizedBox(width: 4),
              Text(
                lembur.kategoriDisplay,
                style: AppConstants.captionStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lembur.deskripsiPekerjaan,
            style: AppConstants.captionStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (lembur.canEdit || lembur.canSubmit) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (lembur.canDelete)
                  TextButton.icon(
                    onPressed: () => _deleteLembur(lembur),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.errorColor,
                    ),
                  ),
                if (lembur.canEdit)
                  TextButton.icon(
                    onPressed: () => _navigateToForm(lembur: lembur),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                if (lembur.canSubmit)
                  TextButton.icon(
                    onPressed: () => _submitLembur(lembur),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Ajukan'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.primaryColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'draft':
        color = AppConstants.textSecondaryColor;
        break;
      case 'submitted':
        color = AppConstants.warningColor;
        break;
      case 'approved':
        color = AppConstants.successColor;
        break;
      case 'rejected':
        color = AppConstants.errorColor;
        break;
      case 'processed':
        color = AppConstants.primaryColor;
        break;
      default:
        color = AppConstants.textSecondaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        Lembur.fromJson({'status': status, 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String(), 'lembur_id': '', 'karyawan_id': '', 'tanggal_lembur': DateTime.now().toIso8601String(), 'jam_mulai': '', 'jam_selesai': '', 'total_jam': 0, 'kategori_lembur': '', 'multiplier': 0, 'deskripsi_pekerjaan': ''}).statusDisplay,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_summary == null) {
      return const LoadingWidget(message: 'Memuat summary...');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: AppConstants.titleStyle,
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildSummaryCard('Total Lembur', '${_summary!['total_lembur']}', Icons.work, AppConstants.primaryColor),
              _buildSummaryCard('Draft', '${_summary!['draft']}', Icons.drafts, AppConstants.textSecondaryColor),
              _buildSummaryCard('Diajukan', '${_summary!['submitted']}', Icons.send, AppConstants.warningColor),
              _buildSummaryCard('Disetujui', '${_summary!['approved']}', Icons.check_circle, AppConstants.successColor),
            ],
          ),
          const SizedBox(height: 16),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Jam Disetujui', style: AppConstants.subtitleStyle),
                const SizedBox(height: 8),
                Text(
                  '${(_summary!['total_jam_approved'] ?? 0).toStringAsFixed(1)} jam',
                  style: AppConstants.titleStyle.copyWith(color: AppConstants.primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: AppConstants.titleStyle.copyWith(color: color, fontSize: 24)),
          Text(label, style: AppConstants.captionStyle, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter Lembur', style: AppConstants.subtitleStyle),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Status')),
                ...['draft', 'submitted', 'approved', 'rejected', 'processed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                Navigator.pop(context);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLemburDetail(Lembur lembur) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LemburDetailScreen(lembur: lembur),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToForm({Lembur? lembur}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LemburFormScreen(lembur: lembur),
      ),
    ).then((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Form Screen untuk tambah/edit
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
  
  final _tanggalController = TextEditingController();
  final _jamMulaiController = TextEditingController();
  final _jamSelesaiController = TextEditingController();
  final _deskripsiController = TextEditingController();
  
  String _kategori = 'reguler';
  File? _photoFile;
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
    }

    if (widget.lembur != null) {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(widget.lembur!.tanggalLembur);
      _jamMulaiController.text = widget.lembur!.jamMulai;
      _jamSelesaiController.text = widget.lembur!.jamSelesai;
      _deskripsiController.text = widget.lembur!.deskripsiPekerjaan;
      _kategori = widget.lembur!.kategoriLembur;
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
    if (image != null) {
      setState(() => _photoFile = File(image.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final formData = FormData.fromMap({
        'tanggal_lembur': _tanggalController.text,
        'jam_mulai': _jamMulaiController.text,
        'jam_selesai': _jamSelesaiController.text,
        'kategori_lembur': _kategori,
        'deskripsi_pekerjaan': _deskripsiController.text,
        if (_photoFile != null)
          'bukti_foto': await MultipartFile.fromFile(_photoFile!.path),
      });

      final url = widget.lembur == null
          ? AppConstants.lemburSubmitEndpoint
          : '${AppConstants.lemburUpdateEndpoint}/${widget.lembur!.lemburId}';

      await _dio.post(url, data: formData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lembur == null ? 'Lembur berhasil ditambahkan' : 'Lembur berhasil diupdate'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppConstants.errorColor),
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
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _tanggalController,
              decoration: const InputDecoration(labelText: 'Tanggal'),
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
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jamMulaiController,
              decoration: const InputDecoration(labelText: 'Jam Mulai (HH:mm)'),
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jamSelesaiController,
              decoration: const InputDecoration(labelText: 'Jam Selesai (HH:mm)'),
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _kategori,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: const [
                DropdownMenuItem(value: 'reguler', child: Text('Reguler (1.5x)')),
                DropdownMenuItem(value: 'hari_libur', child: Text('Hari Libur (2x)')),
                DropdownMenuItem(value: 'hari_besar', child: Text('Hari Besar (2.5x)')),
              ],
              onChanged: (v) => setState(() => _kategori = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deskripsiController,
              decoration: const InputDecoration(labelText: 'Deskripsi Pekerjaan'),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            if (_photoFile != null)
              Image.file(_photoFile!, height: 200),
            ElevatedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_photoFile == null ? 'Ambil Foto' : 'Ganti Foto'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

// Detail Screen
class LemburDetailScreen extends StatelessWidget {
  final Lembur lembur;

  const LemburDetailScreen({super.key, required this.lembur});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Lembur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tanggal', style: AppConstants.captionStyle),
                Text(DateFormat('dd MMMM yyyy').format(lembur.tanggalLembur), style: AppConstants.bodyStyle),
                const Divider(height: 24),
                Text('Waktu', style: AppConstants.captionStyle),
                Text('${lembur.jamMulai} - ${lembur.jamSelesai}', style: AppConstants.bodyStyle),
                const Divider(height: 24),
                Text('Total Jam', style: AppConstants.captionStyle),
                Text('${lembur.totalJam} jam', style: AppConstants.bodyStyle),
                const Divider(height: 24),
                Text('Kategori', style: AppConstants.captionStyle),
                Text(lembur.kategoriDisplay, style: AppConstants.bodyStyle),
                const Divider(height: 24),
                Text('Status', style: AppConstants.captionStyle),
                Text(lembur.statusDisplay, style: AppConstants.bodyStyle),
                const Divider(height: 24),
                Text('Deskripsi', style: AppConstants.captionStyle),
                Text(lembur.deskripsiPekerjaan, style: AppConstants.bodyStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}