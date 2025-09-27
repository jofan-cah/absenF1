// lib/models/lembur.dart
class Lembur {
  final String lemburId;
  final String karyawanId;
  final String? absenId;
  final DateTime tanggalLembur;
  final String jamMulai;
  final String jamSelesai;
  final double totalJam;
  final String kategoriLembur; // reguler, hari_libur, hari_besar
  final double multiplier;
  final String deskripsiPekerjaan;
  final String? buktiFoto;
  final String status; // draft, submitted, approved, rejected, processed
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
    required this.kategoriLembur,
    required this.multiplier,
    required this.deskripsiPekerjaan,
    this.buktiFoto,
    required this.status,
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
      kategoriLembur: json['kategori_lembur'] ?? 'reguler',
      multiplier: _parseDouble(json['multiplier']),
      deskripsiPekerjaan: json['deskripsi_pekerjaan'] ?? '',
      buktiFoto: json['bukti_foto'],
      status: json['status'] ?? 'draft',
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
      'kategori_lembur': kategoriLembur,
      'multiplier': multiplier,
      'deskripsi_pekerjaan': deskripsiPekerjaan,
      'bukti_foto': buktiFoto,
      'status': status,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get canEdit => status == 'draft' || status == 'rejected';
  bool get canSubmit => status == 'draft';
  bool get canDelete => status == 'draft';

  String get kategoriDisplay {
    switch (kategoriLembur) {
      case 'reguler':
        return 'Reguler (1.5x)';
      case 'hari_libur':
        return 'Hari Libur (2x)';
      case 'hari_besar':
        return 'Hari Besar (2.5x)';
      default:
        return kategoriLembur;
    }
  }

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

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}