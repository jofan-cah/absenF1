// lib/screens/ijin_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../models/ijin.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';

class IjinDetailScreen extends StatefulWidget {
  final Ijin ijin;

  const IjinDetailScreen({super.key, required this.ijin});

  @override
  State<IjinDetailScreen> createState() => _IjinDetailScreenState();
}

class _IjinDetailScreenState extends State<IjinDetailScreen> {
  late Dio _dio;
  late StorageService _storage;
  Ijin? _ijinDetail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _storage = await StorageService.getInstance();
    _dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    final token = await _storage.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _dio.options.headers['Accept'] = 'application/json';
    }

    await _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final response = await _dio.get(
        '${AppConstants.ijinDetailEndpoint}/${widget.ijin.ijinId}',
      );

      if (response.data['success'] == true) {
        setState(() {
          _ijinDetail = Ijin.fromJson(response.data['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _ijinDetail = widget.ijin;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelIjin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: AppConstants.warningColor),
            const SizedBox(width: 8),
            const Text('Konfirmasi'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin membatalkan pengajuan ijin ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dio.delete(
          '${AppConstants.ijinCancelEndpoint}/${widget.ijin.ijinId}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengajuan ijin berhasil dibatalkan'),
              backgroundColor: AppConstants.successColor,
            ),
          );
          Navigator.pop(context, true); // Return true to refresh list
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = 'Gagal membatalkan ijin';
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Ijin')),
        body: const LoadingWidget(message: 'Memuat detail ijin...'),
      );
    }

    final ijin = _ijinDetail ?? widget.ijin;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Detail Ijin'),
        actions: [
          if (ijin.canCancel)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _cancelIjin,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // Status Card
          _buildStatusCard(ijin),
          const SizedBox(height: AppConstants.paddingMedium),

          // Informasi Ijin
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_note,
                        color: AppConstants.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Informasi Ijin', style: AppConstants.subtitleStyle),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                _buildInfoRow('Jenis Ijin', ijin.ijinType?.name ?? 'Unknown'),
                _buildInfoRow(
                  'Periode',
                  '${DateFormat('dd MMM yyyy').format(ijin.dateFrom)} - ${DateFormat('dd MMM yyyy').format(ijin.dateTo)}',
                ),
                _buildInfoRow('Total Hari', '${ijin.totalDays} hari'),
                _buildInfoRow('Alasan', ijin.reason),

                // Info tambahan untuk shift swap
                if (ijin.originalShiftDate != null) ...[
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Tanggal Piket Asli',
                    DateFormat('dd MMM yyyy (EEEE)').format(ijin.originalShiftDate!),
                  ),
                ],
                if (ijin.replacementShiftDate != null) ...[
                  _buildInfoRow(
                    'Tanggal Pengganti',
                    DateFormat('dd MMM yyyy (EEEE)').format(ijin.replacementShiftDate!),
                  ),
                ],

                const Divider(height: 24),
                _buildInfoRow(
                  'Tanggal Pengajuan',
                  DateFormat('dd MMM yyyy HH:mm').format(ijin.createdAt),
                ),
              ],
            ),
          ),

          // Status Approval
          const SizedBox(height: AppConstants.paddingMedium),
          _buildApprovalStatus(ijin),

          // Notes
          if (ijin.coordinatorNote != null || ijin.adminNote != null) ...[
            const SizedBox(height: AppConstants.paddingMedium),
            _buildNotesCard(ijin),
          ],

          // Action Button
          if (ijin.canCancel) ...[
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton.icon(
              onPressed: _cancelIjin,
              icon: const Icon(Icons.cancel),
              label: const Text('Batalkan Pengajuan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(Ijin ijin) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (ijin.status) {
      case 'approved':
        statusColor = AppConstants.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'Disetujui';
        break;
      case 'rejected':
        statusColor = AppConstants.errorColor;
        statusIcon = Icons.cancel;
        statusText = 'Ditolak';
        break;
      default:
        statusColor = AppConstants.warningColor;
        statusIcon = Icons.pending;
        statusText = 'Menunggu Persetujuan';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [statusColor, statusColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: AppConstants.titleStyle.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ijin.statusLabel,
            style: AppConstants.bodyStyle.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatus(Ijin ijin) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.approval,
                  color: AppConstants.warningColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text('Status Persetujuan', style: AppConstants.subtitleStyle),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),

          // Koordinator Status
          _buildApprovalStep(
            'Koordinator',
            ijin.coordinatorStatus,
            ijin.coordinatorNote,
          ),

          const SizedBox(height: 12),

          // Admin Status
          _buildApprovalStep(
            'Admin',
            ijin.adminStatus,
            ijin.adminNote,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStep(String role, String status, String? note) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = AppConstants.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'Disetujui';
        break;
      case 'rejected':
        statusColor = AppConstants.errorColor;
        statusIcon = Icons.cancel;
        statusText = 'Ditolak';
        break;
      default:
        statusColor = AppConstants.textSecondaryColor;
        statusIcon = Icons.pending;
        statusText = 'Menunggu';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: AppConstants.captionStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(Ijin ijin) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.textSecondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note,
                  color: AppConstants.textSecondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text('Catatan', style: AppConstants.subtitleStyle),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),

          if (ijin.coordinatorNote != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(
                  color: AppConstants.warningColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan Koordinator',
                    style: AppConstants.captionStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppConstants.warningColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ijin.coordinatorNote!,
                    style: AppConstants.bodyStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (ijin.adminNote != null) ...[
            Container(
              width: double.infinity,
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
                  Text(
                    'Catatan Admin',
                    style: AppConstants.captionStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ijin.adminNote!,
                    style: AppConstants.bodyStyle,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppConstants.captionStyle),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppConstants.bodyStyle.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}