// lib/models/ijin.dart - VERSI FIXED WITH PHOTO SUPPORT
class Ijin {
  final String ijinId;
  final String karyawanId;
  final String? ijinTypeId;
  final DateTime dateFrom;
  final DateTime dateTo;
  final int totalDays;
  final String reason;
  final String? photoPath; // ✅ TAMBAH FIELD PHOTO
  final String? photoUrl;  // ✅ TAMBAH FIELD PHOTO URL (signed URL dari S3)
  final DateTime? originalShiftDate;
  final DateTime? replacementShiftDate;
  final String status;
  final String coordinatorStatus;
  final String adminStatus;
  final String? coordinatorId;
  final String? coordinatorNote;
  final String? adminNote;
  final String? approvedByUserId;
  final DateTime? approvedAt;
  final String? rejectedByUserId;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final IjinType? ijinType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ijin({
    required this.ijinId,
    required this.karyawanId,
    this.ijinTypeId,
    required this.dateFrom,
    required this.dateTo,
    required this.totalDays,
    required this.reason,
    this.photoPath, // ✅ TAMBAH
    this.photoUrl,  // ✅ TAMBAH
    this.originalShiftDate,
    this.replacementShiftDate,
    required this.status,
    required this.coordinatorStatus,
    required this.adminStatus,
    this.coordinatorId,
    this.coordinatorNote,
    this.adminNote,
    this.approvedByUserId,
    this.approvedAt,
    this.rejectedByUserId,
    this.rejectedAt,
    this.rejectionReason,
    this.ijinType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ijin.fromJson(Map<String, dynamic> json) {
    try {
      return Ijin(
        ijinId: json['ijin_id']?.toString() ?? '',
        karyawanId: json['karyawan_id']?.toString() ?? '',
        ijinTypeId: json['ijin_type_id']?.toString(),
        dateFrom: _parseDate(json['date_from']) ?? DateTime.now(),
        dateTo: _parseDate(json['date_to']) ?? DateTime.now(),
        totalDays: _parseInt(json['total_days']) ?? 0,
        reason: json['reason']?.toString() ?? '',
        photoPath: json['photo_path']?.toString(), // ✅ TAMBAH
        photoUrl: json['photo_url']?.toString(),   // ✅ TAMBAH (signed URL dari backend)
        originalShiftDate: _parseDate(json['original_shift_date']),
        replacementShiftDate: _parseDate(json['replacement_shift_date']),
        status: json['status']?.toString() ?? 'pending',
        coordinatorStatus: json['coordinator_status']?.toString() ?? 'pending',
        adminStatus: json['admin_status']?.toString() ?? 'pending',
        coordinatorId: json['coordinator_id']?.toString(),
        coordinatorNote: json['coordinator_note']?.toString(),
        adminNote: json['admin_note']?.toString(),
        approvedByUserId: json['approved_by_user_id']?.toString(),
        approvedAt: _parseDateTime(json['approved_at']),
        rejectedByUserId: json['rejected_by_user_id']?.toString(),
        rejectedAt: _parseDateTime(json['rejected_at']),
        rejectionReason: json['rejection_reason']?.toString(),
        ijinType: json['ijin_type'] != null
            ? IjinType.fromJson(json['ijin_type'])
            : null,
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Ijin: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ijin_id': ijinId,
      'karyawan_id': karyawanId,
      'ijin_type_id': ijinTypeId,
      'date_from': dateFrom.toIso8601String().split('T')[0],
      'date_to': dateTo.toIso8601String().split('T')[0],
      'total_days': totalDays,
      'reason': reason,
      'photo_path': photoPath, // ✅ TAMBAH
      'photo_url': photoUrl,   // ✅ TAMBAH
      'original_shift_date': originalShiftDate?.toIso8601String().split('T')[0],
      'replacement_shift_date':
          replacementShiftDate?.toIso8601String().split('T')[0],
      'status': status,
      'coordinator_status': coordinatorStatus,
      'admin_status': adminStatus,
      'coordinator_id': coordinatorId,
      'coordinator_note': coordinatorNote,
      'admin_note': adminNote,
      'approved_by_user_id': approvedByUserId,
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_by_user_id': rejectedByUserId,
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'ijin_type': ijinType?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper parsers
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      return DateTime.parse(value.toString());
    } catch (e) {
      print('Error parsing date: $value - $e');
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value;
      return DateTime.parse(value.toString());
    } catch (e) {
      print('Error parsing datetime: $value - $e');
      return null;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    try {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.parse(value.toString());
    } catch (e) {
      print('Error parsing int: $value - $e');
      return null;
    }
  }

  // Helper methods
  bool get canCancel => status == 'pending';
  
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty; // ✅ TAMBAH

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  String get statusLabel {
    if (status == 'approved') {
      return 'Disetujui';
    } else if (status == 'rejected') {
      return 'Ditolak';
    } else {
      // Pending - show detail status
      if (coordinatorStatus == 'rejected') {
        return 'Ditolak oleh Koordinator';
      } else if (adminStatus == 'rejected') {
        return 'Ditolak oleh Admin';
      } else if (coordinatorStatus == 'pending') {
        return 'Menunggu Koordinator';
      } else if (adminStatus == 'pending') {
        return 'Menunggu Admin';
      }
      return 'Sedang Diproses';
    }
  }
}

class IjinType {
  final String ijinTypeId;
  final String name;
  final String code;
  final String? description;
  final bool isActive;

  IjinType({
    required this.ijinTypeId,
    required this.name,
    required this.code,
    this.description,
    required this.isActive,
  });

  factory IjinType.fromJson(Map<String, dynamic> json) {
    try {
      return IjinType(
        ijinTypeId: json['ijin_type_id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown',
        code: json['code']?.toString() ?? '',
        description: json['description']?.toString(),
        isActive: json['is_active'] == true || json['is_active'] == 1,
      );
    } catch (e) {
      print('Error parsing IjinType: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'ijin_type_id': ijinTypeId,
      'name': name,
      'code': code,
      'description': description,
      'is_active': isActive,
    };
  }
}