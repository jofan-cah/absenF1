// lib/models/shift.dart
class Shift {
  final String shiftId;
  final String name;
  final String? code;
  final String startTime;
  final String endTime;
  final String? breakStart;
  final String? breakEnd;
  final int? breakDuration;
  final int? lateTolerance;
  final int? earlyCheckoutTolerance;
  final bool isOvernight;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Shift({
    required this.shiftId,
    required this.name,
    this.code,
    required this.startTime,
    required this.endTime,
    this.breakStart,
    this.breakEnd,
    this.breakDuration,
    this.lateTolerance,
    this.earlyCheckoutTolerance,
    required this.isOvernight,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      shiftId: json['shift_id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'],
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      breakStart: json['break_start'],
      breakEnd: json['break_end'],
      breakDuration: json['break_duration'],
      lateTolerance: json['late_tolerance'],
      earlyCheckoutTolerance: json['early_checkout_tolerance'],
      isOvernight: json['is_overnight'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_id': shiftId,
      'name': name,
      'code': code,
      'start_time': startTime,
      'end_time': endTime,
      'break_start': breakStart,
      'break_end': breakEnd,
      'break_duration': breakDuration,
      'late_tolerance': lateTolerance,
      'early_checkout_tolerance': earlyCheckoutTolerance,
      'is_overnight': isOvernight,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}