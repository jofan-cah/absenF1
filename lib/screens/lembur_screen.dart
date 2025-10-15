// lib/screens/lembur_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/lembur.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/custom_card.dart';
import 'lembur_start_screen.dart';
import 'lembur_finish_screen.dart';
import 'lembur_detail_screen.dart';

class LemburScreen extends StatefulWidget {
  const LemburScreen({Key? key}) : super(key: key);

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Dio _dio;
  late StorageService _storage;

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

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadLemburList(), _loadSummary()]);
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

      print('=== LEMBUR API RESPONSE ===');
      print('Full Response: ${response.data}');

      if (response.data['success'] == true) {
        // ✅ FIX: response.data['data'] langsung adalah List
        final lemburListJson = response.data['data'] as List;

        setState(() {
          _lemburList = lemburListJson.map<Lembur>((json) {
            try {
              return Lembur.fromJson(json);
            } catch (e, stackTrace) {
              print('❌ ERROR PARSING ITEM: $e');
              print('Stack: $stackTrace');
              rethrow;
            }
          }).toList();
        });

        print('✅ Berhasil parse ${_lemburList.length} lembur');
      }
    } catch (e, stackTrace) {
      print('❌ LOAD LEMBUR ERROR: $e');
      print('Stack trace: $stackTrace');
      _showError('Gagal memuat data lembur: ${e.toString()}');
    }
  }

  Future<void> _loadSummary() async {
    try {
      final response = await _dio.get(
        AppConstants.lemburMyListEndpoint,
        queryParameters: {'month': _selectedMonth, 'year': _selectedYear},
      );

      if (response.data['success'] == true) {
        setState(() {
          _summary = response.data['summary'];
        });
      }
    } catch (e) {
      // Silent fail for summary
    }
  }

  Future<void> _submitLembur(Lembur lembur) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Submit lembur untuk disetujui?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.post(
          '${AppConstants.lemburSubmitApprovalEndpoint}/${lembur.lemburId}/submit',
        );
        _showSuccess('Lembur berhasil disubmit');
        await _loadData();
      } catch (e) {
        _showError('Gagal submit lembur: ${e.toString()}');
      }
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
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.errorColor,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.delete(
          '${AppConstants.lemburDeleteEndpoint}/${lembur.lemburId}',
        );
        _showSuccess('Lembur berhasil dihapus');
        await _loadData();
      } catch (e) {
        _showError('Gagal menghapus lembur: ${e.toString()}');
      }
    }
  }

  void _navigateToStart() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LemburStartScreen()),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _navigateToFinish(Lembur lembur) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LemburFinishScreen(lembur: lembur),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _navigateToDetail(Lembur lembur) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LemburDetailScreen(lembur: lembur),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Lembur', style: AppConstants.subtitleStyle),
            const SizedBox(height: 16),

            // Filter Status
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
              },
            ),
            const SizedBox(height: 16),

            // Filter Bulan
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
                        child: Text(
                          DateFormat(
                            'MMMM',
                            'id_ID',
                          ).format(DateTime(2024, month)),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMonth = value);
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
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Terapkan Filter'),
              ),
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Lembur'),
        elevation: 0,
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
        children: [_buildLemburList(), _buildSummary()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToStart(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Lembur'),
        backgroundColor: AppConstants.primaryColor,
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
            Icon(
              Icons.work_off,
              size: 80,
              color: AppConstants.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text('Belum ada data lembur', style: AppConstants.bodyStyle),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _navigateToStart(),
              child: const Text('Mulai Lembur Baru'),
            ),
          ],
        ),
      );
    }

    // Cek apakah ada lembur in-progress
    final inProgressLembur = _lemburList.where((l) => l.isInProgress).toList();
    final otherLemburs = _lemburList.where((l) => !l.isInProgress).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // Card In-Progress (jika ada)
          if (inProgressLembur.isNotEmpty) ...[
            Text(
              'Sedang Berjalan',
              style: AppConstants.subtitleStyle.copyWith(
                color: AppConstants.warningColor,
              ),
            ),
            const SizedBox(height: 8),
            ...inProgressLembur.map((lembur) => _buildInProgressCard(lembur)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // Lembur lainnya
          if (otherLemburs.isNotEmpty)
            Text('Riwayat Lembur', style: AppConstants.subtitleStyle),
          const SizedBox(height: 8),
          ...otherLemburs.map((lembur) => _buildLemburCard(lembur)),
        ],
      ),
    );
  }

  Widget _buildInProgressCard(Lembur lembur) {
    // ✅ FIX: Convert UTC ke Local Timezone
    DateTime? startedAtLocal;
    if (lembur.startedAt != null) {
      startedAtLocal = lembur.startedAt!.toLocal(); // ← PENTING!
    }

    // Hitung durasi dari waktu lokal
    final duration = startedAtLocal != null
        ? DateTime.now().difference(startedAtLocal)
        : Duration.zero;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.warningColor.withOpacity(0.1),
              AppConstants.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.warningColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pending_actions,
                    color: AppConstants.warningColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lembur Sedang Berjalan',
                        style: AppConstants.subtitleStyle.copyWith(
                          color: AppConstants.warningColor,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'EEEE, dd MMM yyyy',
                          'id_ID',
                        ).format(lembur.tanggalLembur),
                        style: AppConstants.captionStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mulai', style: AppConstants.captionStyle),
                    Text(
                      // ✅ FIX: Tampilkan waktu lokal WIB
                      startedAtLocal != null
                          ? DateFormat('HH:mm').format(startedAtLocal)
                          : (lembur.jamMulai ?? '-'),
                      style: AppConstants.subtitleStyle,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppConstants.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${hours}h ${minutes}m',
                    style: AppConstants.bodyStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.warningColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToFinish(lembur),
                icon: const Icon(Icons.check_circle),
                label: const Text('SELESAI LEMBUR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.successColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLemburCard(Lembur lembur) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _navigateToDetail(lembur),
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
                      DateFormat(
                        'EEEE, dd MMM yyyy',
                        'id_ID',
                      ).format(lembur.tanggalLembur),
                      style: AppConstants.subtitleStyle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lembur.jamMulai} - ${lembur.jamSelesai}',
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(lembur.status),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: AppConstants.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                '${lembur.totalJam.toStringAsFixed(1)} jam',
                style: AppConstants.bodyStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.attach_money,
                size: 18,
                color: AppConstants.textSecondaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lembur.estimasiTunjangan,
                  style: AppConstants.captionStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lembur.deskripsiPekerjaan,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppConstants.captionStyle,
          ),

          // Action buttons untuk draft
          if (lembur.canEdit || lembur.canSubmit || lembur.canDelete) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (lembur.canSubmit)
                  TextButton.icon(
                    onPressed: () => _submitLembur(lembur),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Submit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.primaryColor,
                    ),
                  ),
                if (lembur.canDelete)
                  TextButton.icon(
                    onPressed: () => _deleteLembur(lembur),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.errorColor,
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
        Lembur(
          lemburId: '',
          karyawanId: '',
          tanggalLembur: DateTime.now(),
          jamMulai: '',
          jamSelesai: '',
          totalJam: 0,
          deskripsiPekerjaan: '',
          status: status,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).statusDisplay,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_isLoading || _summary == null) {
      return const LoadingWidget(message: 'Memuat summary...');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_selectedYear, _selectedMonth))}',
            style: AppConstants.titleStyle.copyWith(fontSize: 20),
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
              _buildSummaryCard(
                'Total Lembur',
                '${_summary!['total'] ?? 0}',
                Icons.work,
                AppConstants.primaryColor,
              ),
              _buildSummaryCard(
                'Draft',
                '${_summary!['draft'] ?? 0}',
                Icons.drafts,
                AppConstants.textSecondaryColor,
              ),
              _buildSummaryCard(
                'Diajukan',
                '${_summary!['submitted'] ?? 0}',
                Icons.send,
                AppConstants.warningColor,
              ),
              _buildSummaryCard(
                'Disetujui',
                '${_summary!['approved'] ?? 0}',
                Icons.check_circle,
                AppConstants.successColor,
              ),
            ],
          ),
          const SizedBox(height: 16),

          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, color: AppConstants.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Total Jam Disetujui',
                      style: AppConstants.subtitleStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_summary!['total_jam'] ?? 0).toStringAsFixed(1)} jam',
                  style: AppConstants.titleStyle.copyWith(
                    fontSize: 32,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return CustomCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppConstants.titleStyle.copyWith(fontSize: 24, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppConstants.captionStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
