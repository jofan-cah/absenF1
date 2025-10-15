// lib/screens/lembur_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/lembur.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/custom_card.dart';
import 'lembur_finish_screen.dart';

class LemburDetailScreen extends StatefulWidget {
  final Lembur lembur;

  const LemburDetailScreen({Key? key, required this.lembur}) : super(key: key);

  @override
  State<LemburDetailScreen> createState() => _LemburDetailScreenState();
}

class _LemburDetailScreenState extends State<LemburDetailScreen> {
  late Dio _dio;
  late StorageService _storage;
  late Lembur _lembur;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _lembur = widget.lembur;
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

    await _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);

    try {
      final response = await _dio.get(
        '${AppConstants.lemburDetailEndpoint}/${_lembur.lemburId}',
      );

      print(response);

      if (response.data['success'] == true) {
        setState(() {
          _lembur = Lembur.fromJson(response.data['data']['lembur']);
        });
      }
    } catch (e) {
      _showError('Gagal memuat detail: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitLembur() async {
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
          '${AppConstants.lemburSubmitApprovalEndpoint}/${_lembur.lemburId}/submit',
        );
        _showSuccess('Lembur berhasil disubmit');
        await _loadDetail();
      } catch (e) {
        _showError('Gagal submit lembur: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteLembur() async {
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
          '${AppConstants.lemburDeleteEndpoint}/${_lembur.lemburId}',
        );
        if (mounted) {
          _showSuccess('Lembur berhasil dihapus');
          Navigator.pop(context, true);
        }
      } catch (e) {
        _showError('Gagal menghapus lembur: ${e.toString()}');
      }
    }
  }

  void _navigateToFinish() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LemburFinishScreen(lembur: _lembur),
      ),
    );

    if (result == true) {
      _loadDetail();
    }
  }

  Future<void> _showError(String message) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LemburFinishScreen(lembur: _lembur),
      ),
    );

    if (result == true) {
      _loadDetail();
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
        title: const Text('Detail Lembur'),
        elevation: 0,
        actions: [
          if (_lembur.canDelete)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteLembur,
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Memuat detail...')
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                children: [
                  // Status Card
                  _buildStatusCard(),
                  const SizedBox(height: 16),

                  // Info Dasar
                  _buildInfoCard(),
                  const SizedBox(height: 16),

                  // Waktu & Durasi
                  _buildTimeCard(),
                  const SizedBox(height: 16),

                  // Deskripsi
                  _buildDescriptionCard(),
                  const SizedBox(height: 16),

                  // Bukti Foto
                  _buildPhotoCard(),
                  const SizedBox(height: 16),

                  // Info Approval/Rejection (jika ada)
                  if (_lembur.status == 'approved' ||
                      _lembur.status == 'rejected')
                    _buildApprovalCard(),

                  const SizedBox(height: 16),

                  // Action Button
                  if (_lembur.canFinish) _buildFinishButton(),
                  if (_lembur.canSubmit) _buildSubmitButton(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;

    switch (_lembur.status) {
      case 'draft':
        statusColor = AppConstants.textSecondaryColor;
        statusIcon = Icons.drafts;
        break;
      case 'submitted':
        statusColor = AppConstants.warningColor;
        statusIcon = Icons.send;
        break;
      case 'approved':
        statusColor = AppConstants.successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppConstants.errorColor;
        statusIcon = Icons.cancel;
        break;
      case 'processed':
        statusColor = AppConstants.primaryColor;
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = AppConstants.textSecondaryColor;
        statusIcon = Icons.help;
    }

    return CustomCard(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), AppConstants.cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: AppConstants.captionStyle),
                  const SizedBox(height: 4),
                  Text(
                    _lembur.statusDisplay,
                    style: AppConstants.titleStyle.copyWith(
                      fontSize: 20,
                      color: statusColor,
                    ),
                  ),
                  if (_lembur.submittedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Diajukan: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(_lembur.submittedAt!)}',
                      style: AppConstants.captionStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Informasi Dasar', style: AppConstants.subtitleStyle),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('ID Lembur', _lembur.lemburId),
          _buildInfoRow(
            'Tanggal',
            DateFormat(
              'EEEE, dd MMMM yyyy',
              'id_ID',
            ).format(_lembur.tanggalLembur),
          ),
          if (_lembur.absenId != null)
            _buildInfoRow('ID Absen', _lembur.absenId!),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Waktu & Durasi', style: AppConstants.subtitleStyle),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jam Mulai', style: AppConstants.captionStyle),
                    const SizedBox(height: 4),
                    Text(
                      _lembur.jamMulai,
                      style: AppConstants.subtitleStyle.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                ),
                child: const Icon(Icons.arrow_forward, size: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Jam Selesai', style: AppConstants.captionStyle),
                    const SizedBox(height: 4),
                    Text(
                      _lembur.jamSelesai,
                      style: AppConstants.subtitleStyle.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: AppConstants.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Jam', style: AppConstants.captionStyle),
                    const SizedBox(height: 4),
                    Text(
                      '${_lembur.totalJam.toStringAsFixed(1)} jam',
                      style: AppConstants.titleStyle.copyWith(
                        fontSize: 24,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Estimasi Tunjangan',
                      style: AppConstants.captionStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lembur.estimasiTunjangan,
                      style: AppConstants.bodyStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    Text(
                      _lembur.estimasiNominal,
                      style: AppConstants.captionStyle.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Deskripsi Pekerjaan', style: AppConstants.subtitleStyle),
            ],
          ),
          const Divider(height: 24),
          Text(
            _lembur.deskripsiPekerjaan,
            style: AppConstants.bodyStyle.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    print('🖼️ === BUILD PHOTO CARD ===');
    print('buktiFoto: ${_lembur.buktiFoto}');

    // ✅ Cek buktiFoto (bukan buktiFotoUrl)
    final hasPhoto = _lembur.buktiFoto != null && _lembur.buktiFoto!.isNotEmpty;
    print('hasPhoto: $hasPhoto');

    // ✅ Build full S3 URL dari buktiFoto
    String? imageUrl;
    if (hasPhoto) {
      // Jika sudah full URL
      if (_lembur.buktiFoto!.startsWith('http')) {
        imageUrl = _lembur.buktiFoto;
      }
      // Jika path relatif S3, build URL
      else {
        // ⚠️ SESUAIKAN dengan URL S3 bucket kamu!
        imageUrl = '${AppConstants.baseUrl}/storage/${_lembur.buktiFoto}';
        // Atau langsung ke S3:
        // imageUrl = 'https://your-bucket.s3.region.amazonaws.com/${_lembur.buktiFoto}';
      }
      print('📸 Image URL: $imageUrl');
    }
    print('========================');

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_camera, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text('Bukti Foto', style: AppConstants.subtitleStyle),
            ],
          ),
          const Divider(height: 24),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              child: Image.network(
                imageUrl, // ✅ Pakai URL yang sudah di-build
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    color: AppConstants.backgroundColor,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('❌ IMAGE ERROR: $error');
                  print('❌ URL: $imageUrl');
                  return Container(
                    height: 250,
                    color: AppConstants.backgroundColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: AppConstants.textSecondaryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat foto',
                            style: AppConstants.captionStyle,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SelectableText(
                              imageUrl,
                              style: AppConstants.captionStyle.copyWith(
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(
                  color: AppConstants.textSecondaryColor.withOpacity(0.3),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: AppConstants.textSecondaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text('Tidak ada foto', style: AppConstants.captionStyle),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard() {
    final isApproved = _lembur.status == 'approved';
    final color = isApproved
        ? AppConstants.successColor
        : AppConstants.errorColor;
    final icon = isApproved ? Icons.check_circle : Icons.cancel;
    final title = isApproved ? 'Informasi Persetujuan' : 'Informasi Penolakan';

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: AppConstants.subtitleStyle),
            ],
          ),
          const Divider(height: 24),
          if (isApproved) ...[
            if (_lembur.approvedAt != null)
              _buildInfoRow(
                'Tanggal Approval',
                DateFormat(
                  'dd MMM yyyy, HH:mm',
                  'id_ID',
                ).format(_lembur.approvedAt!),
              ),
            if (_lembur.approvalNotes != null &&
                _lembur.approvalNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Catatan', style: AppConstants.captionStyle),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  border: Border.all(
                    color: AppConstants.successColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _lembur.approvalNotes!,
                  style: AppConstants.bodyStyle,
                ),
              ),
            ],
          ] else ...[
            if (_lembur.rejectedAt != null)
              _buildInfoRow(
                'Tanggal Penolakan',
                DateFormat(
                  'dd MMM yyyy, HH:mm',
                  'id_ID',
                ).format(_lembur.rejectedAt!),
              ),
            if (_lembur.rejectionReason != null &&
                _lembur.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Alasan Penolakan', style: AppConstants.captionStyle),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  border: Border.all(
                    color: AppConstants.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _lembur.rejectionReason!,
                  style: AppConstants.bodyStyle,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppConstants.captionStyle),
          ),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyStyle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _navigateToFinish,
          icon: const Icon(Icons.check_circle, size: 24),
          label: const Text(
            'SELESAI LEMBUR',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.successColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _submitLembur,
        icon: const Icon(Icons.send),
        label: const Text(
          'SUBMIT UNTUK APPROVAL',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
        ),
      ),
    );
  }
}
