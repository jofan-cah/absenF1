// lib/models/lembur.dart - DENGAN DEFAULT KATEGORI
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
  
  // ✅ Ada di backend dengan default (tapi TIDAK ditampilkan ke user)
  final String kategoriLembur; // default: "reguler"
  final double multiplier; // default: 1.5 (tergantung kategori)
  
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
    required this.deskripsiPekerjaan,
    this.buktiFoto,
    required this.status,
    this.kategoriLembur = 'reguler', // ← Default value
    this.multiplier = 1.5, // ← Default value
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
    try {
      return Lembur(
        lemburId: json['lembur_id']?.toString() ?? '',
        karyawanId: json['karyawan_id']?.toString() ?? '',
        absenId: json['absen_id']?.toString(),
        tanggalLembur: _parseDateTime(json['tanggal_lembur']) ?? DateTime.now(),
        jamMulai: json['jam_mulai']?.toString() ?? '',
        jamSelesai: json['jam_selesai']?.toString() ?? '',
        totalJam: _parseDouble(json['total_jam']),
        deskripsiPekerjaan: json['deskripsi_pekerjaan']?.toString() ?? '',
        buktiFoto: json['bukti_foto']?.toString(),
        status: json['status']?.toString() ?? 'draft',
        
        // ✅ Parse kategori & multiplier dengan default value
        kategoriLembur: json['kategori_lembur']?.toString() ?? 'reguler',
        multiplier: _parseDouble(json['multiplier']) != 0.0 
            ? _parseDouble(json['multiplier']) 
            : 1.5, // default jika null atau 0
        
        submittedAt: _parseDateTime(json['submitted_at']),
        submittedVia: json['submitted_via']?.toString(),
        approvedByUserId: json['approved_by_user_id']?.toString(),
        approvedAt: _parseDateTime(json['approved_at']),
        approvalNotes: json['approval_notes']?.toString(),
        rejectedByUserId: json['rejected_by_user_id']?.toString(),
        rejectedAt: _parseDateTime(json['rejected_at']),
        rejectionReason: json['rejection_reason']?.toString(),
        tunjanganKaryawanId: json['tunjangan_karyawan_id']?.toString(),
        createdByUserId: json['created_by_user_id']?.toString(),
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      );
    } catch (e, stackTrace) {
      print('===== ERROR PARSING LEMBUR =====');
      print('Error: $e');
      print('StackTrace: $stackTrace');
      print('JSON: $json');
      rethrow;
    }
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
      'kategori_lembur': kategoriLembur,
      'multiplier': multiplier,
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

  // ✅ Getter untuk display kategori
  String get kategoriDisplay {
    switch (kategoriLembur) {
      case 'reguler':
        return 'Reguler';
      case 'hari_libur':
        return 'Hari Libur';
      case 'hari_besar':
        return 'Hari Besar';
      default:
        return kategoriLembur;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing DateTime: $value');
        return null;
      }
    }
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }
}