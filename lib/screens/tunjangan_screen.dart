// lib/screens/tunjangan_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/tunjangan_karyawan.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';

class TunjanganScreen extends StatefulWidget {
  const TunjanganScreen({super.key});

  @override
  State<TunjanganScreen> createState() => _TunjanganScreenState();
}

class _TunjanganScreenState extends State<TunjanganScreen> with SingleTickerProviderStateMixin {
  late StorageService _storage;
  late Dio _dio;
  late TabController _tabController;
  
  List<TunjanganKaryawan> _tunjanganList = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedStatus;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      _loadTunjanganList(),
      _loadSummary(),
    ]);
  }

  Future<void> _loadTunjanganList() async {
    try {
      final response = await _dio.get(
        AppConstants.tunjanganMyListEndpoint,
        queryParameters: {
          'month': _selectedMonth,
          'year': _selectedYear,
          if (_selectedStatus != null) 'status': _selectedStatus,
          if (_selectedType != null) 'type': _selectedType,
          'per_page': 50,
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _tunjanganList = (response.data['data'] as List)
              .map((json) => TunjanganKaryawan.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Gagal memuat data tunjangan: ${e.toString()}');
    }
  }

  Future<void> _loadSummary() async {
    try {
      final response = await _dio.get(
        AppConstants.tunjanganSummaryEndpoint,
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
      // Silent error
    }
  }

  Future<void> _requestTunjangan(TunjanganKaryawan tunjangan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text('Request pencairan tunjangan ${tunjangan.tunjanganType?.name ?? ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.post('${AppConstants.tunjanganRequestEndpoint}/${tunjangan.tunjanganKaryawanId}/request');
        _showSuccess('Request tunjangan berhasil');
        await _loadData();
      } catch (e) {
        _showError('Gagal request tunjangan: ${e.toString()}');
      }
    }
  }

  Future<void> _confirmReceived(TunjanganKaryawan tunjangan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Konfirmasi bahwa tunjangan sudah diterima?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.post('${AppConstants.tunjanganConfirmEndpoint}/${tunjangan.tunjanganKaryawanId}/confirm-received');
        _showSuccess('Konfirmasi penerimaan tunjangan berhasil');
        await _loadData();
      } catch (e) {
        _showError('Gagal konfirmasi: ${e.toString()}');
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
        title: const Text('Tunjangan'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Uang Makan'),
            Tab(text: 'Uang Kuota'),
            Tab(text: 'Uang Lembur'),
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
          _buildTunjanganList(null),
          _buildTunjanganList('UANG_MAKAN'),
          _buildTunjanganList('UANG_KUOTA'),
          _buildTunjanganList('UANG_LEMBUR'),
        ],
      ),
    );
  }

  Widget _buildTunjanganList(String? type) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Memuat data tunjangan...');
    }

    var filteredList = _tunjanganList;
    if (type != null) {
      filteredList = _tunjanganList.where((t) => t.tunjanganType?.code == type).toList();
    }

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.money_off, size: 64, color: AppConstants.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              'Belum ada data tunjangan',
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
        itemCount: filteredList.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSummaryHeader();
          }
          final tunjangan = filteredList[index - 1];
          return _buildTunjanganCard(tunjangan);
        },
      ),
    );
  }

  Widget _buildSummaryHeader() {
    if (_summary == null) return const SizedBox.shrink();

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary ${DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth))}',
            style: AppConstants.subtitleStyle,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total',
                  '${_summary!['total_semua_tunjangan'] ?? 0}',
                  Icons.receipt_long,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Nominal',
                  NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0)
                      .format(_summary!['total_nominal_semua'] ?? 0),
                  Icons.payments,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppConstants.primaryColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppConstants.captionStyle),
            Text(value, style: AppConstants.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildTunjanganCard(TunjanganKaryawan tunjangan) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showTunjanganDetail(tunjangan),
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
                      tunjangan.tunjanganType?.name ?? 'Unknown',
                      style: AppConstants.subtitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM').format(tunjangan.periodStart)} - ${DateFormat('dd MMM yyyy').format(tunjangan.periodEnd)}',
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(tunjangan.status),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nominal', style: AppConstants.captionStyle),
                  Text(
                    currencyFormat.format(tunjangan.totalAmount),
                    style: AppConstants.bodyStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ],
              ),
              if (tunjangan.tunjanganType?.code == 'UANG_MAKAN') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Hari Kerja', style: AppConstants.captionStyle),
                    Text(
                      '${tunjangan.hariKerjaFinal ?? tunjangan.quantity} hari',
                      style: AppConstants.bodyStyle,
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (tunjangan.canRequest || tunjangan.canConfirm) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (tunjangan.canRequest)
                  ElevatedButton.icon(
                    onPressed: () => _requestTunjangan(tunjangan),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (tunjangan.canConfirm)
                  ElevatedButton.icon(
                    onPressed: () => _confirmReceived(tunjangan),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Konfirmasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.successColor,
                      foregroundColor: Colors.white,
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
      case 'pending':
        color = AppConstants.textSecondaryColor;
        break;
      case 'requested':
        color = AppConstants.warningColor;
        break;
      case 'approved':
        color = AppConstants.successColor;
        break;
      case 'received':
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
        TunjanganKaryawan.fromJson({
          'tunjangan_karyawan_id': '',
          'karyawan_id': '',
          'tunjangan_type_id': '',
          'period_start': DateTime.now().toIso8601String(),
          'period_end': DateTime.now().toIso8601String(),
          'amount': 0,
          'quantity': 0,
          'total_amount': 0,
          'status': status,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).statusDisplay,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
            Text('Filter Tunjangan', style: AppConstants.subtitleStyle),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Status')),
                ...['pending', 'requested', 'approved', 'received']
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

  void _showTunjanganDetail(TunjanganKaryawan tunjangan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TunjanganDetailScreen(tunjangan: tunjangan),
      ),
    ).then((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Detail Screen
class TunjanganDetailScreen extends StatelessWidget {
  final TunjanganKaryawan tunjangan;

  const TunjanganDetailScreen({super.key, required this.tunjangan});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Tunjangan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jenis Tunjangan', style: AppConstants.captionStyle),
                Text(tunjangan.tunjanganType?.name ?? 'Unknown', style: AppConstants.subtitleStyle),
                const Divider(height: 24),
                Text('Periode', style: AppConstants.captionStyle),
                Text(
                  '${DateFormat('dd MMM yyyy').format(tunjangan.periodStart)} - ${DateFormat('dd MMM yyyy').format(tunjangan.periodEnd)}',
                  style: AppConstants.bodyStyle,
                ),
                const Divider(height: 24),
                if (tunjangan.tunjanganType?.code == 'UANG_MAKAN') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hari Kerja Asli', style: AppConstants.captionStyle),
                          Text('${tunjangan.hariKerjaAsli ?? 0} hari', style: AppConstants.bodyStyle),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Hari Potong', style: AppConstants.captionStyle),
                          Text('${tunjangan.hariPotongPenalti ?? 0} hari', style: AppConstants.bodyStyle),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Hari Kerja Final', style: AppConstants.captionStyle),
                  Text('${tunjangan.hariKerjaFinal ?? 0} hari', style: AppConstants.bodyStyle),
                  const Divider(height: 24),
                ],
                Text('Nominal per unit', style: AppConstants.captionStyle),
                Text(currencyFormat.format(tunjangan.amount), style: AppConstants.bodyStyle),
                const Divider(height: 24),
                Text('Total Nominal', style: AppConstants.captionStyle),
                Text(
                  currencyFormat.format(tunjangan.totalAmount),
                  style: AppConstants.titleStyle.copyWith(color: AppConstants.primaryColor),
                ),
                const Divider(height: 24),
                Text('Status', style: AppConstants.captionStyle),
                Text(tunjangan.statusDisplay, style: AppConstants.bodyStyle),
                if (tunjangan.notes != null) ...[
                  const Divider(height: 24),
                  Text('Catatan', style: AppConstants.captionStyle),
                  Text(tunjangan.notes!, style: AppConstants.bodyStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}