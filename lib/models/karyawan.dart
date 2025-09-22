// lib/models/karyawan.dart
class Karyawan {
  final String karyawanId;
  final String userId;
  final String? departmentId;
  final String nip;
  final String fullName;
  final String? position;
  final String? phone;
  final String? address;
  final DateTime? hireDate;
  final DateTime? birthDate;
  final String? gender;
  final String? photo;
  final String employmentStatus;
  final String? staffStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  Karyawan({
    required this.karyawanId,
    required this.userId,
    this.departmentId,
    required this.nip,
    required this.fullName,
    this.position,
    this.phone,
    this.address,
    this.hireDate,
    this.birthDate,
    this.gender,
    this.photo,
    required this.employmentStatus,
    this.staffStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Karyawan.fromJson(Map<String, dynamic> json) {
    return Karyawan(
      karyawanId: json['karyawan_id'] ?? '',
      userId: json['user_id'] ?? '',
      departmentId: json['department_id'],
      nip: json['nip'] ?? '',
      fullName: json['full_name'] ?? '',
      position: json['position'],
      phone: json['phone'],
      address: json['address'],
      hireDate: json['hire_date'] != null
          ? DateTime.parse(json['hire_date'])
          : null,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      gender: json['gender'],
      photo: json['photo'],
      employmentStatus: json['employment_status'] ?? 'active',
      staffStatus: json['staff_status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'karyawan_id': karyawanId,
      'user_id': userId,
      'department_id': departmentId,
      'nip': nip,
      'full_name': fullName,
      'position': position,
      'phone': phone,
      'address': address,
      'hire_date': hireDate?.toIso8601String(),
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'photo': photo,
      'employment_status': employmentStatus,
      'staff_status': staffStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}