// lib/models/lembur.dart
class Lembur {
  final String lemburId;
  final String karyawanId;
  final String? absenId;
  final DateTime tanggalLembur;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  final String deskripsiPekerjaan;
  final String? buktiFoto;
  final String status; // draft, submitted, approved, rejected, processed
  
  // Field lama yang masih ada di DB (tapi tidak dipakai lagi)
  final String? kategoriLembur; // DEPRECATED - still in DB with default value
  final double? multiplier; // DEPRECATED - still in DB with default value
  
  final DateTime? submittedAt;
  final String? submittedVia;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final String? approvalNotes;
  final String? rejectedByUserId;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? tunjanganKaryawanId;
  final String? createdByUserId;
  final String? coordinatorId;
  final String? koordinatorStatus; // pending, approved, rejected
  final DateTime? koordinatorApprovedAt;
  final String? koordinatorNotes;
  final DateTime? koordinatorRejectedAt;
  final DateTime? startedAt; // Timestamp mulai lembur
  final DateTime? completedAt; // Timestamp selesai lembur
  final DateTime createdAt;
  final DateTime updatedAt;

  Lembur({
    required this.lemburId,
    required this.karyawanId,
    this.absenId,
    required this.tanggalLembur,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    required this.deskripsiPekerjaan,
    this.buktiFoto,
    required this.status,
    this.kategoriLembur, // DEPRECATED
    this.multiplier, // DEPRECATED
    this.submittedAt,
    this.submittedVia,
    this.approvedByUserId,
    this.approvedAt,
    this.approvalNotes,
    this.rejectedByUserId,
    this.rejectedAt,
    this.rejectionReason,
    this.tunjanganKaryawanId,
    this.createdByUserId,
    this.coordinatorId,
    this.koordinatorStatus,
    this.koordinatorApprovedAt,
    this.koordinatorNotes,
    this.koordinatorRejectedAt,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lembur.fromJson(Map<String, dynamic> json) {
    return Lembur(
      lemburId: json['lembur_id'] ?? '',
      karyawanId: json['karyawan_id'] ?? '',
      absenId: json['absen_id'],
      tanggalLembur: DateTime.parse(json['tanggal_lembur']),
      jamMulai: json['jam_mulai'] ?? '',
      jamSelesai: json['jam_selesai'] ?? '',
      totalJam: _parseDouble(json['total_jam']),
      deskripsiPekerjaan: json['deskripsi_pekerjaan'] ?? '',
      buktiFoto: json['bukti_foto'],
      status: json['status'] ?? 'draft',
      kategoriLembur: json['kategori_lembur'], // Parse tapi tidak dipakai
      multiplier: json['multiplier'] != null ? _parseDouble(json['multiplier']) : null, // Parse tapi tidak dipakai
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      submittedVia: json['submitted_via'],
      approvedByUserId: json['approved_by_user_id'],
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      approvalNotes: json['approval_notes'],
      rejectedByUserId: json['rejected_by_user_id'],
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'])
          : null,
      rejectionReason: json['rejection_reason'],
      tunjanganKaryawanId: json['tunjangan_karyawan_id'],
      createdByUserId: json['created_by_user_id'],
      coordinatorId: json['coordinator_id'],
      koordinatorStatus: json['koordinator_status'],
      koordinatorApprovedAt: json['koordinator_approved_at'] != null
          ? DateTime.parse(json['koordinator_approved_at'])
          : null,
      koordinatorNotes: json['koordinator_notes'],
      koordinatorRejectedAt: json['koordinator_rejected_at'] != null
          ? DateTime.parse(json['koordinator_rejected_at'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lembur_id': lemburId,
      'karyawan_id': karyawanId,
      'absen_id': absenId,
      'tanggal_lembur': tanggalLembur.toIso8601String().split('T')[0],
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'total_jam': totalJam,
      'deskripsi_pekerjaan': deskripsiPekerjaan,
      'bukti_foto': buktiFoto,
      'status': status,
      'kategori_lembur': kategoriLembur, // Tetap serialize untuk backward compatibility
      'multiplier': multiplier, // Tetap serialize untuk backward compatibility
      'submitted_at': submittedAt?.toIso8601String(),
      'submitted_via': submittedVia,
      'approved_by_user_id': approvedByUserId,
      'approved_at': approvedAt?.toIso8601String(),
      'approval_notes': approvalNotes,
      'rejected_by_user_id': rejectedByUserId,
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'tunjangan_karyawan_id': tunjanganKaryawanId,
      'created_by_user_id': createdByUserId,
      'coordinator_id': coordinatorId,
      'koordinator_status': koordinatorStatus,
      'koordinator_approved_at': koordinatorApprovedAt?.toIso8601String(),
      'koordinator_notes': koordinatorNotes,
      'koordinator_rejected_at': koordinatorRejectedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get canEdit => status == 'draft' && completedAt == null;
  bool get canSubmit => status == 'draft' && completedAt != null;
  bool get canDelete => status == 'draft';
  bool get canFinish => status == 'draft' && startedAt != null && completedAt == null;
  bool get isInProgress => startedAt != null && completedAt == null;

  String get statusDisplay {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Diajukan';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'processed':
        return 'Selesai';
      default:
        return status;
    }
  }

  String get statusColor {
    switch (status) {
      case 'draft':
        return '#9E9E9E'; // Grey
      case 'submitted':
        return '#FF9800'; // Orange
      case 'approved':
        return '#4CAF50'; // Green
      case 'rejected':
        return '#F44336'; // Red
      case 'processed':
        return '#2196F3'; // Blue
      default:
        return '#9E9E9E';
    }
  }

  // Estimasi tunjangan berdasarkan total jam
  String get estimasiTunjangan {
    if (totalJam >= 4) {
      return '2x uang makan';
    } else if (totalJam > 0) {
      return '1x uang makan';
    }
    return 'Tidak ada tunjangan';
  }

  // Estimasi nominal (asumsi 20k untuk staff biasa)
  String get estimasiNominal {
    if (totalJam >= 4) {
      return 'Rp 40.000 (atau Rp 30.000 untuk PKWTT)';
    } else if (totalJam > 0) {
      return 'Rp 20.000 (atau Rp 15.000 untuk PKWTT)';
    }
    return 'Rp 0';
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Copy with method untuk update data
  Lembur copyWith({
    String? lemburId,
    String? karyawanId,
    String? absenId,
    DateTime? tanggalLembur,
    String? jamMulai,
    String? jamSelesai,
    double? totalJam,
    String? deskripsiPekerjaan,
    String? buktiFoto,
    String? status,
    String? kategoriLembur,
    double? multiplier,
    DateTime? submittedAt,
    String? submittedVia,
    String? approvedByUserId,
    DateTime? approvedAt,
    String? approvalNotes,
    String? rejectedByUserId,
    DateTime? rejectedAt,
    String? rejectionReason,
    String? tunjanganKaryawanId,
    String? createdByUserId,
    String? coordinatorId,
    String? koordinatorStatus,
    DateTime? koordinatorApprovedAt,
    String? koordinatorNotes,
    DateTime? koordinatorRejectedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lembur(
      lemburId: lemburId ?? this.lemburId,
      karyawanId: karyawanId ?? this.karyawanId,
      absenId: absenId ?? this.absenId,
      tanggalLembur: tanggalLembur ?? this.tanggalLembur,
      jamMulai: jamMulai ?? this.jamMulai,
      jamSelesai: jamSelesai ?? this.jamSelesai,
      totalJam: totalJam ?? this.totalJam,
      deskripsiPekerjaan: deskripsiPekerjaan ?? this.deskripsiPekerjaan,
      buktiFoto: buktiFoto ?? this.buktiFoto,
      status: status ?? this.status,
      kategoriLembur: kategoriLembur ?? this.kategoriLembur,
      multiplier: multiplier ?? this.multiplier,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedVia: submittedVia ?? this.submittedVia,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      rejectedByUserId: rejectedByUserId ?? this.rejectedByUserId,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      tunjanganKaryawanId: tunjanganKaryawanId ?? this.tunjanganKaryawanId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      coordinatorId: coordinatorId ?? this.coordinatorId,
      koordinatorStatus: koordinatorStatus ?? this.koordinatorStatus,
      koordinatorApprovedAt: koordinatorApprovedAt ?? this.koordinatorApprovedAt,
      koordinatorNotes: koordinatorNotes ?? this.koordinatorNotes,
      koordinatorRejectedAt: koordinatorRejectedAt ?? this.koordinatorRejectedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}