// lib/screens/jadwal_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  late Dio _dio;
  late StorageService _storage;
  
  List<dynamic> _jadwals = [];
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
    
    await _loadJadwals();
  }

  Future<void> _loadJadwals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.get(
        AppConstants.jadwalEndpoint,
        queryParameters: {
          'month': _selectedMonth.month,
          'year': _selectedMonth.year,
        },
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _jadwals = response.data['data']['jadwals'] ?? [];
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
            content: Text('Gagal memuat jadwal: ${e.toString()}'),
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
      lastDate: DateTime(2030),
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
      await _loadJadwals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Jadwal Kerja'),
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
          // Month selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            color: Colors.white,
            child: Row(
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
          ),
          
          // Jadwal list
          Expanded(
            child: _isLoading
                ? const LoadingWidget(message: 'Memuat jadwal...')
                : RefreshIndicator(
                    onRefresh: _loadJadwals,
                    child: _jadwals.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppConstants.paddingMedium),
                            itemCount: _jadwals.length,
                            itemBuilder: (context, index) {
                              return _buildJadwalCard(_jadwals[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJadwalCard(Map<String, dynamic> jadwal) {
    final date = DateTime.parse(jadwal['date']);
    final shift = jadwal['shift'];
    final absen = jadwal['absen'];
    
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
              if (absen != null)
                _buildStatusBadge(absen['status']),
            ],
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          
          Row(
            children: [
              Icon(Icons.work, size: 16, color: AppConstants.textSecondaryColor),
              const SizedBox(width: 4),
              Text(shift['name'], style: AppConstants.bodyStyle),
            ],
          ),
          const SizedBox(height: 4),
          
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: AppConstants.textSecondaryColor),
              const SizedBox(width: 4),
              Text(
                '${shift['start_time']} - ${shift['end_time']}',
                style: AppConstants.bodyStyle,
              ),
            ],
          ),
          
          if (absen != null && absen['clock_in'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.login, size: 16, color: AppConstants.successColor),
                const SizedBox(width: 4),
                Text(
                  'Clock In: ${absen['clock_in']}',
                  style: AppConstants.captionStyle,
                ),
                if (absen['clock_out'] != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.logout, size: 16, color: AppConstants.errorColor),
                  const SizedBox(width: 4),
                  Text(
                    'Clock Out: ${absen['clock_out']}',
                    style: AppConstants.captionStyle,
                  ),
                ],
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
              Icons.calendar_today_outlined,
              size: 64,
              color: AppConstants.textSecondaryColor,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Tidak Ada Jadwal',
              style: AppConstants.subtitleStyle,
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak ada jadwal untuk bulan ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
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