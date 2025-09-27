// lib/models/tunjangan_type.dart
class TunjanganType {
  final String tunjanganTypeId;
  final String name;
  final String code; // UANG_MAKAN, UANG_KUOTA, UANG_LEMBUR
  final String category; // harian, mingguan, bulanan
  final double baseAmount;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TunjanganType({
    required this.tunjanganTypeId,
    required this.name,
    required this.code,
    required this.category,
    required this.baseAmount,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TunjanganType.fromJson(Map<String, dynamic> json) {
    return TunjanganType(
      tunjanganTypeId: json['tunjangan_type_id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      category: json['category'] ?? '',
      baseAmount: _parseDouble(json['base_amount']),
      description: json['description'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tunjangan_type_id': tunjanganTypeId,
      'name': name,
      'code': code,
      'category': category,
      'base_amount': baseAmount,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}