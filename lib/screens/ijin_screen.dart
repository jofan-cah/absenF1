// lib/screens/ijin_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/ijin.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';
import 'ijin_form_screens.dart'; // ✅ TAMBAHKAN INI
import 'ijin_detail_screen.dart'; // ✅ TAMBAHKAN INI

class IjinScreen extends StatefulWidget {
  const IjinScreen({super.key});

  @override
  State<IjinScreen> createState() => _IjinScreenState();
}

class _IjinScreenState extends State<IjinScreen>
    with SingleTickerProviderStateMixin {
  late StorageService _storage;
  late Dio _dio;
  late TabController _tabController;

  List<Ijin> _ijinList = [];
  List<IjinType> _ijinTypes = [];
  bool _isLoading = true;

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
      connectTimeout: const Duration(
          milliseconds: AppConstants.connectionTimeout),
      receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeout),
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
      _loadIjinTypes(),
      _loadIjinHistory(),
    ]);
  }

  Future<void> _loadIjinTypes() async {
    try {
      final response = await _dio.get(AppConstants.ijinTypesEndpoint);

      if (response.data['success'] == true) {
        setState(() {
          _ijinTypes = (response.data['data'] as List)
              .map((json) => IjinType.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _loadIjinHistory() async {
    try {
      final queryParams = <String, dynamic>{
        'per_page': 50,
      };

      if (_selectedStatus != null) queryParams['status'] = _selectedStatus;
      if (_selectedType != null) queryParams['type'] = _selectedType;

      final response = await _dio.get(
        AppConstants.ijinMyHistoryEndpoint,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        setState(() {
          _ijinList = (response.data['data'] as List)
              .map((json) => Ijin.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Gagal memuat data ijin: ${e.toString()}');
    }
  }

  Future<void> _cancelIjin(Ijin ijin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Batalkan pengajuan ijin ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.delete(
            '${AppConstants.ijinCancelEndpoint}/${ijin.ijinId}');
        _showSuccess('Pengajuan ijin berhasil dibatalkan');
        await _loadIjinHistory();
      } catch (e) {
        _showError('Gagal membatalkan ijin: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: AppConstants.errorColor),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: AppConstants.successColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Pengajuan Ijin'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
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
          _buildIjinList(null),
          _buildIjinList('pending'),
          _buildIjinList('approved'),
          _buildIjinList('rejected'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showIjinTypeSelector(),
        icon: const Icon(Icons.add),
        label: const Text('Ajukan Ijin'),
      ),
    );
  }

  Widget _buildIjinList(String? statusFilter) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Memuat data ijin...');
    }

    var filteredList = _ijinList;
    if (statusFilter != null) {
      filteredList = _ijinList.where((i) => i.status == statusFilter).toList();
    }

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy,
                size: 64, color: AppConstants.textSecondaryColor),
            const SizedBox(height: 16),
            Text(
              'Belum ada data ijin',
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
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final ijin = filteredList[index];
          return _buildIjinCard(ijin);
        },
      ),
    );
  }

 Widget _buildIjinCard(Ijin ijin) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      onTap: () => _showIjinDetail(ijin),
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
                      ijin.ijinType?.name ?? 'Unknown',
                      style: AppConstants.subtitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(ijin.dateFrom)} - ${DateFormat('dd MMM yyyy').format(ijin.dateTo)}',
                      style: AppConstants.captionStyle,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(ijin.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 16, color: AppConstants.textSecondaryColor),
              const SizedBox(width: 4),
              Text(
                '${ijin.totalDays} hari',
                style: AppConstants.captionStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ijin.reason,
            style: AppConstants.captionStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (ijin.canCancel) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelIjin(ijin),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Batalkan'),
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
    String text;

    switch (status) {
      case 'pending':
        color = AppConstants.warningColor;
        text = 'Menunggu';
        break;
      case 'approved':
        color = AppConstants.successColor;
        text = 'Disetujui';
        break;
      case 'rejected':
        color = AppConstants.errorColor;
        text = 'Ditolak';
        break;
      default:
        color = AppConstants.textSecondaryColor;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
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
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter Ijin', style: AppConstants.subtitleStyle),
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipe Ijin',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Semua Tipe')),
                ..._ijinTypes.map((type) => DropdownMenuItem(
                      value: type.ijinTypeId,
                      child: Text(type.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedType = value);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _selectedStatus = null;
                      });
                      Navigator.pop(context);
                      _loadIjinHistory();
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadIjinHistory();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showIjinTypeSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pilih Jenis Ijin', style: AppConstants.subtitleStyle),
            const SizedBox(height: 16),
            ..._ijinTypes.map((type) {
              IconData icon;
              Color color;

              switch (type.code) {
                case 'sick_leave':
                  icon = Icons.sick;
                  color = AppConstants.errorColor;
                  break;
                case 'annual_leave':
                  icon = Icons.beach_access;
                  color = AppConstants.primaryColor;
                  break;
                case 'personal_leave':
                  icon = Icons.person;
                  color = AppConstants.warningColor;
                  break;
                case 'shift_swap':
                  icon = Icons.swap_horiz;
                  color = AppConstants.successColor;
                  break;
                case 'compensation_leave':
                  icon = Icons.event_available;
                  color = Colors.purple;
                  break;
                default:
                  icon = Icons.event_note;
                  color = AppConstants.textSecondaryColor;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(type.name),
                  subtitle: type.description != null
                      ? Text(
                          type.description!,
                          style: AppConstants.captionStyle,
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToIjinForm(type);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _navigateToIjinForm(IjinType type) {
    if (type.code == 'shift_swap') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShiftSwapFormScreen(ijinType: type),
        ),
      ).then((_) => _loadData());
    } else if (type.code == 'compensation_leave') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompensationLeaveFormScreen(ijinType: type),
        ),
      ).then((_) => _loadData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IjinFormScreen(ijinType: type),
        ),
      ).then((_) => _loadData());
    }
  }

  void _showIjinDetail(Ijin ijin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IjinDetailScreen(ijin: ijin),
      ),
    ).then((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

