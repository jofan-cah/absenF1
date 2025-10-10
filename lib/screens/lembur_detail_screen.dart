// lib/screens/lembur_detail_screen.dart - DETAIL SCREEN
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/lembur.dart';
import '../widgets/custom_card.dart';

class LemburDetailScreen extends StatelessWidget {
  final Lembur lembur;

  const LemburDetailScreen({super.key, required this.lembur});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Lembur'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        children: [
          // STATUS CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(lembur.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor(lembur.status).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(lembur.status), color: _getStatusColor(lembur.status), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status', style: AppConstants.captionStyle),
                      Text(
                        lembur.statusDisplay,
                        style: AppConstants.subtitleStyle.copyWith(color: _getStatusColor(lembur.status)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // INFO LEMBUR
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informasi Lembur', style: AppConstants.subtitleStyle),
                const Divider(height: 24),
                _buildInfoRow('Tanggal', DateFormat('dd MMMM yyyy', 'id_ID').format(lembur.tanggalLembur)),
                _buildInfoRow('Jam Mulai', lembur.jamMulai),
                _buildInfoRow('Jam Selesai', lembur.jamSelesai),
                _buildInfoRow('Total Jam', '${lembur.totalJam.toStringAsFixed(1)} jam'),
                _buildInfoRow('Deskripsi', lembur.deskripsiPekerjaan, isMultiline: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // BUKTI FOTO
          if (lembur.buktiFoto != null) ...[
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bukti Foto', style: AppConstants.subtitleStyle),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      lembur.buktiFoto!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // APPROVAL INFO
          if (lembur.status == 'approved' || lembur.status == 'processed') ...[
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informasi Persetujuan', style: AppConstants.subtitleStyle),
                  const Divider(height: 24),
                  if (lembur.approvedAt != null)
                    _buildInfoRow('Disetujui pada', DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(lembur.approvedAt!)),
                  if (lembur.approvalNotes != null)
                    _buildInfoRow('Catatan', lembur.approvalNotes!, isMultiline: true),
                ],
              ),
            ),
          ],
          
          // REJECTION INFO
          if (lembur.status == 'rejected') ...[
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informasi Penolakan', style: AppConstants.subtitleStyle),
                  const Divider(height: 24),
                  if (lembur.rejectedAt != null)
                    _buildInfoRow('Ditolak pada', DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(lembur.rejectedAt!)),
                  if (lembur.rejectionReason != null)
                    _buildInfoRow('Alasan', lembur.rejectionReason!, isMultiline: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: isMultiline
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppConstants.captionStyle),
                const SizedBox(height: 4),
                Text(value, style: AppConstants.bodyStyle),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppConstants.captionStyle),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    style: AppConstants.bodyStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'processed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.drafts;
      case 'submitted':
        return Icons.send;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'processed':
        return Icons.done_all;
      default:
        return Icons.info;
    }
  }
}