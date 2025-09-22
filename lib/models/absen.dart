// lib/models/absen.dart
class Absen {
  final String absenId;
  final String karyawanId;
  final String jadwalId;
  final DateTime date;
  final String? clockIn;
  final String? clockInPhoto;
  final double? clockInLatitude;
  final double? clockInLongitude;
  final String? clockInAddress;
  final String? clockOut;
  final String? clockOutPhoto;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final String? clockOutAddress;
  final String status;
  final int? lateMinutes;
  final int? earlyCheckoutMinutes;
  final double? workHours;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Absen({
    required this.absenId,
    required this.karyawanId,
    required this.jadwalId,
    required this.date,
    this.clockIn,
    this.clockInPhoto,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockInAddress,
    this.clockOut,
    this.clockOutPhoto,
    this.clockOutLatitude,
    this.clockOutLongitude,
    this.clockOutAddress,
    required this.status,
    this.lateMinutes,
    this.earlyCheckoutMinutes,
    this.workHours,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Absen.fromJson(Map<String, dynamic> json) {
    return Absen(
      absenId: json['absen_id'] ?? '',
      karyawanId: json['karyawan_id'] ?? '',
      jadwalId: json['jadwal_id'] ?? '',
      date: DateTime.parse(json['date']),
      clockIn: json['clock_in'],
      clockInPhoto: json['clock_in_photo'],
      clockInLatitude: json['clock_in_latitude'] != null
          ? double.parse(json['clock_in_latitude'].toString())
          : null,
      clockInLongitude: json['clock_in_longitude'] != null
          ? double.parse(json['clock_in_longitude'].toString())
          : null,
      clockInAddress: json['clock_in_address'],
      clockOut: json['clock_out'],
      clockOutPhoto: json['clock_out_photo'],
      clockOutLatitude: json['clock_out_latitude'] != null
          ? double.parse(json['clock_out_latitude'].toString())
          : null,
      clockOutLongitude: json['clock_out_longitude'] != null
          ? double.parse(json['clock_out_longitude'].toString())
          : null,
      clockOutAddress: json['clock_out_address'],
      status: json['status'] ?? 'scheduled',
      lateMinutes: json['late_minutes'],
      earlyCheckoutMinutes: json['early_checkout_minutes'],
      workHours: json['work_hours'] != null
          ? double.parse(json['work_hours'].toString())
          : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'absen_id': absenId,
      'karyawan_id': karyawanId,
      'jadwal_id': jadwalId,
      'date': date.toIso8601String(),
      'clock_in': clockIn,
      'clock_in_photo': clockInPhoto,
      'clock_in_latitude': clockInLatitude,
      'clock_in_longitude': clockInLongitude,
      'clock_in_address': clockInAddress,
      'clock_out': clockOut,
      'clock_out_photo': clockOutPhoto,
      'clock_out_latitude': clockOutLatitude,
      'clock_out_longitude': clockOutLongitude,
      'clock_out_address': clockOutAddress,
      'status': status,
      'late_minutes': lateMinutes,
      'early_checkout_minutes': earlyCheckoutMinutes,
      'work_hours': workHours,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}