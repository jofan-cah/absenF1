// lib/utils/constants.dart
import 'package:flutter/material.dart';

class AppConstants {
  // API Configuration
  // static const String baseUrl = 'https://prefast-dev.fiberone.net.id/api';
  static const String baseUrl = 'https://prefast.fiberone.net.id/api';

  // API Endpoints
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';
  static const String meEndpoint = '/me';
  static const String changePasswordEndpoint = '/change-password';

  // Dashboard
  static const String dashboardEndpoint = '/dashboard';
  static const String notificationsEndpoint = '/notifications';

  // Profile
  static const String profileEndpoint = '/profile';
  static const String profilePhotoEndpoint = '/profile/photo';
  static const String profileStatsEndpoint = '/profile/stats';

  // Jadwal
  static const String jadwalEndpoint = '/jadwal';
  static const String jadwalWeeklyEndpoint = '/jadwal/weekly';
  static const String jadwalTodayEndpoint = '/jadwal/today';
  static const String jadwalTomorrowEndpoint = '/jadwal/tomorrow';
  static const String jadwalRangeEndpoint = '/jadwal/range';

  // Absen
  static const String absenTodayEndpoint = '/absen/today';
  static const String clockInEndpoint = '/absen/clock-in';
  static const String clockOutEndpoint = '/absen/clock-out';
  static const String absenHistoryEndpoint = '/absen/history';

  // Riwayat
  static const String riwayatAbsenEndpoint = '/riwayat/absen';
  static const String riwayatJadwalEndpoint = '/riwayat/jadwal';
  static const String riwayatDetailEndpoint = '/riwayat/detail';
  static const String riwayatYearlyEndpoint = '/riwayat/yearly';
  static const String riwayatPhotosEndpoint = '/riwayat/photos';

  // ========================================
  // LEMBUR (NEW v1.1.0)
  // ========================================
  // Lembur Endpoints
  static const String lemburMyListEndpoint = '/lembur/my-list';
  static const String lemburSummaryEndpoint = '/lembur/summary';
  static const String lemburSubmitEndpoint = '/lembur/submit';
  static const String lemburDetailEndpoint = '/lembur'; // + /{id}
  static const String lemburUpdateEndpoint = '/lembur'; // + /{id}
  static const String lemburDeleteEndpoint = '/lembur'; // + /{id}
  static const String lemburSubmitApprovalEndpoint = '/lembur'; // + /{id}/submit

  // ========================================
  // TUNJANGAN (NEW v1.1.0)
  // ========================================
  static const String tunjanganUangMakanReportEndpoint =
      '/tunjangan/uang-makan/report';
  static const String tunjanganUangKuotaReportEndpoint =
      '/tunjangan/uang-kuota/report';
  static const String tunjanganUangLemburReportEndpoint =
      '/tunjangan/uang-lembur/report';
  static const String tunjanganMyListEndpoint = '/tunjangan/my-list';
  static const String tunjanganSummaryEndpoint = '/tunjangan/summary';
  static const String tunjanganDetailEndpoint = '/tunjangan'; // + /{id}
  static const String tunjanganRequestEndpoint =
      '/tunjangan'; // + /{id}/request
  static const String tunjanganConfirmEndpoint =
      '/tunjangan'; // + /{id}/confirm-received

  static const String ijinTypesEndpoint = '/ijin/types';
  static const String ijinMyHistoryEndpoint = '/ijin/my-history';
  static const String ijinDetailEndpoint = '/ijin'; // + /{id}
  static const String ijinSubmitEndpoint = '/ijin/submit';
  static const String ijinShiftSwapEndpoint = '/ijin/shift-swap';
  static const String ijinCompensationLeaveEndpoint =
      '/ijin/compensation-leave';
  static const String ijinCancelEndpoint = '/ijin'; // + /{id} DELETE
  static const String ijinAvailablePiketDatesEndpoint =
      '/ijin/available-piket-dates';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String karyawanKey = 'karyawan_data';

  // App Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color successColor = Color(0xFF38A169);
  static const Color warningColor = Color(0xFFD69E2E);

  // Text Styles
  static const TextStyle titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: textPrimaryColor,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: textSecondaryColor,
  );

  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Border Radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;

  // Elevation
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // App Info
  static const String appName = 'F1 Absensi';
  static const String appVersion = '1.3.0';
}

// Absen Status
enum AbsenStatus { scheduled, present, late, absent, earlyCheckout }

// Employment Status
enum EmploymentStatus { active, inactive, suspended, terminated }

// Staff Status
enum StaffStatus { staff, koordinator, wakilKoordinator }
