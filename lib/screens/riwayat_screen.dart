// lib/screens/riwayat_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  late Dio _dio;
  late StorageService _storage;
  
  List<dynamic> _riwayatAbsen = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

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
    
    await _loadRiwayat();
  }

  Future<void> _loadRiwayat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.get(
        AppConstants.riwayatAbsenEndpoint,
        queryParameters: {
          'month': _selectedMonth.month,
          'year': _selectedMonth.year,
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _riwayatAbsen = response.data['data'] ?? [];
          _summary = response.data['meta']['summary'];
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat riwayat: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppConstants.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      await _loadRiwayat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat Absen'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector & Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: AppConstants.subtitleStyle,
                    ),
                    TextButton.icon(
                      onPressed: _selectMonth,
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Ganti Bulan'),
                    ),
                  ],
                ),
                
                if (_summary != null) ...[
                  const SizedBox(height: AppConstants.paddingMedium),
                  _buildSummaryRow(),
                ],
              ],
            ),
          ),
          
          // Riwayat list
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Memuat riwayat...')
                : RefreshIndicator(
                    onRefresh: _loadRiwayat,
                    child: _riwayatAbsen.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppConstants.paddingMedium),
                            itemCount: _riwayatAbsen.length,
                            itemBuilder: (context, index) {
                              return _buildRiwayatCard(_riwayatAbsen[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(child: _buildSummaryItem('Total', '${_summary!['total_jadwal']}', AppConstants.primaryColor)),
        Expanded(child: _buildSummaryItem('Hadir', '${_summary!['hadir']}', AppConstants.successColor)),
        Expanded(child: _buildSummaryItem('Terlambat', '${_summary!['terlambat']}', AppConstants.warningColor)),
        Expanded(child: _buildSummaryItem('Tidak Hadir', '${_summary!['tidak_hadir']}', AppConstants.errorColor)),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppConstants.subtitleStyle.copyWith(color: color),
        ),
        Text(
          label,
          style: AppConstants.captionStyle,
        ),
      ],
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> absen) {
    final date = DateTime.parse(absen['date']);
    final jadwal = absen['jadwal'];
    final shift = jadwal?['shift'];
    
    return CustomCard(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, dd MMMM').format(date),
                style: AppConstants.subtitleStyle,
              ),
              _buildStatusBadge(absen['status']),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          
          if (shift != null) ...[
            Row(
              children: [
                Icon(Icons.work, size: 16, color: AppConstants.textSecondaryColor),
                const SizedBox(width: 4),
                Text(shift['name'], style: AppConstants.bodyStyle),
              ],
            ),
            const SizedBox(height: 4),
          ],
          
          Row(
            children: [
              if (absen['clock_in'] != null) ...[
                Icon(Icons.login, size: 16, color: AppConstants.successColor),
                const SizedBox(width: 4),
                Text('In: ${absen['clock_in']}', style: AppConstants.captionStyle),
              ],
              
              if (absen['clock_out'] != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.logout, size: 16, color: AppConstants.errorColor),
                const SizedBox(width: 4),
                Text('Out: ${absen['clock_out']}', style: AppConstants.captionStyle),
              ],
            ],
          ),
          
          if (absen['work_hours'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: AppConstants.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  'Jam Kerja: ${absen['work_hours']} jam',
                  style: AppConstants.captionStyle,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    String text;
    
    switch (status) {
      case 'present':
        color = AppConstants.successColor;
        text = 'Hadir';
        break;
      case 'late':
        color = AppConstants.warningColor;
        text = 'Terlambat';
        break;
      case 'absent':
        color = AppConstants.errorColor;
        text = 'Tidak Hadir';
        break;
      case 'scheduled':
        color = AppConstants.textSecondaryColor;
        text = 'Belum Absen';
        break;
      default:
        color = AppConstants.textSecondaryColor;
        text = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppConstants.textSecondaryColor,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Tidak Ada Riwayat',
              style: AppConstants.subtitleStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada riwayat absen untuk bulan ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}