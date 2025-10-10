// lib/screens/lembur_screen.dart - LIST & SUMMARY ONLY
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/lembur.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';
import 'lembur_form_screen.dart';
import 'lembur_detail_screen.dart';

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
    setState(() => _isLoading = true);
    await Future.wait([
      _loadLemburList(),
      _loadSummary(),
    ]);
    setState(() => _isLoading = false);
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
      
      // ✅ DEBUG: Print response
      print('===== LEMBUR LIST RESPONSE =====');
      print('Success: ${response.data['success']}');
      print('Data: ${response.data['data']}');
      
      if (response.data['success'] == true) {
        // ✅ FIX: Handle response structure dengan benar
        var dataList;
        
        // Cek apakah data langsung List atau ada pagination
        if (response.data['data'] is List) {
          // Langsung list
          dataList = response.data['data'];
        } else if (response.data['data'] is Map && response.data['data']['data'] != null) {
          // Ada pagination (data.data)
          dataList = response.data['data']['data'];
        } else {
          // Fallback
          dataList = [];
        }
        
        // ✅ DEBUG: Print first item
        if (dataList is List && dataList.isNotEmpty) {
          print('===== FIRST LEMBUR ITEM =====');
          print(dataList[0]);
        }
        
        setState(() {
          _lemburList = (dataList as List)
              .map((json) {
                try {
                  return Lembur.fromJson(json as Map<String, dynamic>);
                } catch (e, stackTrace) {
                  print('===== ERROR PARSING LEMBUR =====');
                  print('JSON: $json');
                  print('Error: $e');
                  print('StackTrace: $stackTrace');
                  rethrow;
                }
              })
              .toList();
        });
      }
    } catch (e, stackTrace) {
      print('===== ERROR LOAD LEMBUR =====');
      print('Error: $e');
      print('StackTrace: $stackTrace');
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
          _summary = response.data['data']['summary'] ?? response.data['data'];
        });
      }
    } catch (e) {
      print('Error loading summary: $e');
    }
  }

  Future<void> _submitLembur(Lembur lembur) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Ajukan lembur ini untuk persetujuan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Ajukan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _dio.post(
        '${AppConstants.lemburSubmitApprovalEndpoint}/${lembur.lemburId}/submit',
      );
      
      if (response.data['success'] == true) {
        _showSuccess('Lembur berhasil diajukan untuk persetujuan');
        await _loadData();
      }
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        _showError(e.response!.data['message'] ?? 'Gagal mengajukan lembur');
      } else {
        _showError('Gagal mengajukan lembur: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteLembur(Lembur lembur) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Hapus lembur ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppConstants.errorColor),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _dio.delete(
        '${AppConstants.lemburDeleteEndpoint}/${lembur.lemburId}',
      );
      
      if (response.data['success'] == true) {
        _showSuccess('Lembur berhasil dihapus');
        await _loadData();
      }
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        _showError(e.response!.data['message'] ?? 'Gagal menghapus lembur');
      } else {
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
            const SizedBox(height: 8),
            Text(
              'Periode: ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth))}',
              style: AppConstants.captionStyle,
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
                      DateFormat('dd MMM yyyy', 'id_ID').format(lembur.tanggalLembur),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lembur.deskripsiPekerjaan,
            style: AppConstants.captionStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (lembur.canEdit || lembur.canSubmit || lembur.canDelete) ...[
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
    String label;
    
    switch (status) {
      case 'draft':
        color = AppConstants.textSecondaryColor;
        label = 'Draft';
        break;
      case 'submitted':
        color = AppConstants.warningColor;
        label = 'Diajukan';
        break;
      case 'approved':
        color = AppConstants.successColor;
        label = 'Disetujui';
        break;
      case 'rejected':
        color = AppConstants.errorColor;
        label = 'Ditolak';
        break;
      case 'processed':
        color = AppConstants.primaryColor;
        label = 'Selesai';
        break;
      default:
        color = AppConstants.textSecondaryColor;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
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
            'Summary ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth))}',
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
              _buildSummaryCard('Total', '${_summary!['total_lembur'] ?? 0}', Icons.work, AppConstants.primaryColor),
              _buildSummaryCard('Draft', '${_summary!['draft'] ?? 0}', Icons.drafts, AppConstants.textSecondaryColor),
              _buildSummaryCard('Diajukan', '${_summary!['submitted'] ?? 0}', Icons.send, AppConstants.warningColor),
              _buildSummaryCard('Disetujui', '${_summary!['approved'] ?? 0}', Icons.check_circle, AppConstants.successColor),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Lembur', style: AppConstants.subtitleStyle),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Semua Status')),
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'submitted', child: Text('Diajukan')),
                DropdownMenuItem(value: 'approved', child: Text('Disetujui')),
                DropdownMenuItem(value: 'rejected', child: Text('Ditolak')),
                DropdownMenuItem(value: 'processed', child: Text('Selesai')),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                Navigator.pop(context);
                _loadData();
              },
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Bulan',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2024, month))),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMonth = value);
                        Navigator.pop(context);
                        _loadData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Tahun',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(3, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedYear = value);
                        Navigator.pop(context);
                        _loadData();
                      }
                    },
                  ),
                ),
              ],
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