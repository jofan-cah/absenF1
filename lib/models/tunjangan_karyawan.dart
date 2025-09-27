// lib/models/tunjangan_karyawan.dart
import 'tunjangan_type.dart';

class TunjanganKaryawan {
  final String tunjanganKaryawanId;
  final String karyawanId;
  final String tunjanganTypeId;
  final String? absenId;
  final String? lemburId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double amount;
  final int quantity;
  final double totalAmount;
  final String status; // pending, requested, approved, received
  final String? notes;
  final DateTime? requestedAt;
  final String? requestedVia;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final DateTime? receivedAt;
  final String? receivedConfirmationPhoto;
  final String? penaltiId;
  final int? hariKerjaAsli;
  final int? hariPotongPenalti;
  final int? hariKerjaFinal;
  final List<Map<String, dynamic>>? history;
  final TunjanganType? tunjanganType; // Relasi
  final DateTime createdAt;
  final DateTime updatedAt;

  TunjanganKaryawan({
    required this.tunjanganKaryawanId,
    required this.karyawanId,
    required this.tunjanganTypeId,
    this.absenId,
    this.lemburId,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    this.notes,
    this.requestedAt,
    this.requestedVia,
    this.approvedByUserId,
    this.approvedAt,
    this.receivedAt,
    this.receivedConfirmationPhoto,
    this.penaltiId,
    this.hariKerjaAsli,
    this.hariPotongPenalti,
    this.hariKerjaFinal,
    this.history,
    this.tunjanganType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TunjanganKaryawan.fromJson(Map<String, dynamic> json) {
    return TunjanganKaryawan(
      tunjanganKaryawanId: json['tunjangan_karyawan_id'] ?? '',
      karyawanId: json['karyawan_id'] ?? '',
      tunjanganTypeId: json['tunjangan_type_id'] ?? '',
      absenId: json['absen_id'],
      lemburId: json['lembur_id'],
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
      amount: _parseDouble(json['amount']),
      quantity: json['quantity'] ?? 0,
      totalAmount: _parseDouble(json['total_amount']),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'])
          : null,
      requestedVia: json['requested_via'],
      approvedByUserId: json['approved_by_user_id'],
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      receivedAt: json['received_at'] != null
          ? DateTime.parse(json['received_at'])
          : null,
      receivedConfirmationPhoto: json['received_confirmation_photo'],
      penaltiId: json['penalti_id'],
      hariKerjaAsli: json['hari_kerja_asli'],
      hariPotongPenalti: json['hari_potong_penalti'],
      hariKerjaFinal: json['hari_kerja_final'],
      history: json['history'] != null
          ? List<Map<String, dynamic>>.from(json['history'])
          : null,
      tunjanganType: json['tunjangan_type'] != null
          ? TunjanganType.fromJson(json['tunjangan_type'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tunjangan_karyawan_id': tunjanganKaryawanId,
      'karyawan_id': karyawanId,
      'tunjangan_type_id': tunjanganTypeId,
      'absen_id': absenId,
      'lembur_id': lemburId,
      'period_start': periodStart.toIso8601String().split('T')[0],
      'period_end': periodEnd.toIso8601String().split('T')[0],
      'amount': amount,
      'quantity': quantity,
      'total_amount': totalAmount,
      'status': status,
      'notes': notes,
      'requested_at': requestedAt?.toIso8601String(),
      'requested_via': requestedVia,
      'approved_by_user_id': approvedByUserId,
      'approved_at': approvedAt?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'received_confirmation_photo': receivedConfirmationPhoto,
      'penalti_id': penaltiId,
      'hari_kerja_asli': hariKerjaAsli,
      'hari_potong_penalti': hariPotongPenalti,
      'hari_kerja_final': hariKerjaFinal,
      'history': history,
      'tunjangan_type': tunjanganType?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get canRequest => status == 'pending';
  bool get canConfirm => status == 'approved';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'requested':
        return 'Diajukan';
      case 'approved':
        return 'Disetujui';
      case 'received':
        return 'Diterima';
      default:
        return status;
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}