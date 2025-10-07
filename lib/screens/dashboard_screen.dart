// lib/screens/dashboard_screen.dart - SUPER MODERN VERSION 🚀
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_card.dart';
import '../widgets/loading_widget.dart';
import 'login_screen.dart';
import 'absen_screen.dart';
import 'jadwal_screen.dart';
import 'riwayat_screen.dart';
import 'profile_screen.dart';
import 'lembur_screen.dart';
import 'tunjangan_screen.dart';
import 'ijin_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late AuthService _authService;
  late StorageService _storage;
  late Dio _dio;

  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 0;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _authService = AuthService();

    _screens.addAll([
      _DashboardContent(
        dashboardData: _dashboardData,
        userData: _userData,
        isLoading: _isLoading,
        onRefresh: _loadDashboardData,
        onLogout: _logout,
      ),
      const AbsenScreen(),
      const JadwalScreen(),
      const RiwayatScreen(),
      const ProfileScreen(),
    ]);

    _initServices();
  }

  Future<void> _initServices() async {
    _storage = await StorageService.getInstance();
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectionTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeout,
        ),
      ),
    );

    final token = await _storage.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      _dio.options.headers['Accept'] = 'application/json';
    }

    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      _userData = await _storage.getUserData();

      final response = await _dio.get(AppConstants.dashboardEndpoint);

      if (response.data['success'] == true) {
        setState(() {
          _dashboardData = response.data['data'];
          _isLoading = false;

          _screens[0] = _DashboardContent(
            dashboardData: _dashboardData,
            userData: _userData,
            isLoading: _isLoading,
            onRefresh: _loadDashboardData,
            onLogout: _logout,
          );
        });
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                _buildNavItem(1, Icons.fingerprint_rounded, 'Absen'),
                _buildNavItem(2, Icons.calendar_month_rounded, 'Jadwal'),
                _buildNavItem(3, Icons.history_rounded, 'Riwayat'),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppConstants.primaryColor
                    : AppConstants.textSecondaryColor,
                size: isSelected ? 28 : 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppConstants.primaryColor
                      : AppConstants.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// DASHBOARD CONTENT - SUPER MODERN! 🎨
// ============================================
class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic>? dashboardData;
  final Map<String, dynamic>? userData;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const _DashboardContent({
    required this.dashboardData,
    required this.userData,
    required this.isLoading,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const LoadingWidget(message: 'Memuat data...')
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildModernAppBar(context),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildGreetingCard(context),
                        const SizedBox(height: 20),
                        _buildTodayScheduleCard(),
                        const SizedBox(height: 20),
                        _buildQuickActions(context),
                        const SizedBox(height: 20),
                        _buildMonthlyStats(),
                        const SizedBox(height: 20),
                        _buildActivityChart(),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    final karyawan = userData?['karyawan'] ?? {};
    final name = karyawan['full_name'] ?? 'User';
    final position = karyawan['position'] ?? 'Staff';

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.primaryColor,
              AppConstants.primaryColor.withOpacity(0.7),
              Colors.purple.withOpacity(0.5),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                position,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.primaryColor,
                  AppConstants.primaryColor.withOpacity(0.7),
                  Colors.purple.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildGreetingCard(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    Color greetingColor;

    if (hour < 12) {
      greeting = 'Selamat Pagi! ☀️';
      greetingIcon = Icons.wb_sunny_rounded;
      greetingColor = Colors.orange;
    } else if (hour < 15) {
      greeting = 'Selamat Siang! 🌤️';
      greetingIcon = Icons.wb_sunny_outlined;
      greetingColor = Colors.amber;
    } else if (hour < 18) {
      greeting = 'Selamat Sore! 🌥️';
      greetingIcon = Icons.wb_cloudy_rounded;
      greetingColor = Colors.deepOrange;
    } else {
      greeting = 'Selamat Malam! 🌙';
      greetingIcon = Icons.nightlight_round;
      greetingColor = Colors.indigo;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            greetingColor.withOpacity(0.2),
            greetingColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: greetingColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: greetingColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(greetingIcon, color: greetingColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: greetingColor,
                  ),
                ),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: greetingColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleCard() {
    final todayJadwal = dashboardData?['today']?['jadwal'];
    final todayAbsen = dashboardData?['today']?['absen'];

    if (todayJadwal == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Tidak ada jadwal hari ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Nikmati hari libur Anda!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryColor.withOpacity(0.8),
            Colors.purple.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Jadwal Hari Ini',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (todayAbsen != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(todayAbsen['status']),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(todayAbsen['status']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.work_outline,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          todayJadwal['shift']['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${todayJadwal['shift']['start_time']} - ${todayJadwal['shift']['end_time']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (todayAbsen != null && todayAbsen['work_hours'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Total Jam Kerja: ${todayAbsen['work_hours']} jam',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
          children: [
            _buildQuickActionCard(
              context,
              'Absen',
              Icons.fingerprint_rounded,
              [AppConstants.primaryColor, Colors.blue.shade300],
              () {
                final dashboardState =
                    context.findAncestorStateOfType<_DashboardScreenState>();
                dashboardState?.setState(() {
                  dashboardState._selectedIndex = 1;
                });
              },
            ),
            _buildQuickActionCard(
              context,
              'Jadwal',
              Icons.calendar_month_rounded,
              [AppConstants.successColor, Colors.green.shade300],
              () {
                final dashboardState =
                    context.findAncestorStateOfType<_DashboardScreenState>();
                dashboardState?.setState(() {
                  dashboardState._selectedIndex = 2;
                });
              },
            ),
            _buildQuickActionCard(
              context,
              'Ijin',
              Icons.event_note_rounded,
              [Colors.orange, Colors.orange.shade300],
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IjinScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              context,
              'Lembur',
              Icons.work_history_rounded,
              [AppConstants.warningColor, Colors.amber.shade300],
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LemburScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              context,
              'Tunjangan',
              Icons.payments_rounded,
              [Colors.green, Colors.green.shade300],
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TunjanganScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              context,
              'Riwayat',
              Icons.history_rounded,
              [Colors.purple, Colors.purple.shade300],
              () {
                final dashboardState =
                    context.findAncestorStateOfType<_DashboardScreenState>();
                dashboardState?.setState(() {
                  dashboardState._selectedIndex = 3;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String label,
    IconData icon,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final stats = dashboardData?['monthly_stats'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik Bulan Ini',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '${stats['total_jadwal'] ?? 0}',
                'Total Jadwal',
                Icons.calendar_today_rounded,
                [AppConstants.primaryColor, Colors.blue.shade300],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '${stats['hadir'] ?? 0}',
                'Hadir',
                Icons.check_circle_rounded,
                [AppConstants.successColor, Colors.green.shade300],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '${stats['terlambat'] ?? 0}',
                'Terlambat',
                Icons.schedule_rounded,
                [AppConstants.warningColor, Colors.amber.shade300],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '${stats['tidak_hadir'] ?? 0}',
                'Tidak Hadir',
                Icons.cancel_rounded,
                [AppConstants.errorColor, Colors.red.shade300],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withOpacity(0.1),
            colors[1].withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors[0].withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors[0], size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colors[0],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colors[0].withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    final stats = dashboardData?['monthly_stats'] ?? {};
    final total = (stats['total_jadwal'] ?? 1);
    final hadir = (stats['hadir'] ?? 0);
    final percentage = (hadir / total * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppConstants.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: AppConstants.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Performa Kehadiran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 150,
                  width: 150,
                  child: CircularProgressIndicator(
                    value: hadir / total,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      AppConstants.successColor,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.successColor,
                      ),
                    ),
                    Text(
                      'Kehadiran',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: AppConstants.successColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pertahankan performa Anda!',
                  style: TextStyle(
                    color: AppConstants.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'present':
        return AppConstants.successColor;
      case 'late':
        return AppConstants.warningColor;
      case 'absent':
        return AppConstants.errorColor;
      default:
        return AppConstants.textSecondaryColor;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'present':
        return 'Hadir';
      case 'late':
        return 'Terlambat';
      case 'absent':
        return 'Tidak Hadir';
      case 'scheduled':
        return 'Belum Absen';
      default:
        return 'Unknown';
    }
  }
}