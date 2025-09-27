// lib/screens/dashboard_screen.dart - Fixed Navigation
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

  // List of screens for bottom navigation
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _authService = AuthService();

    // Initialize screens list
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

          // Update dashboard content screen
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
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: AppConstants.primaryColor,
          unselectedItemColor: AppConstants.textSecondaryColor,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fingerprint_outlined),
              activeIcon: Icon(Icons.fingerprint),
              label: 'Absen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              activeIcon: Icon(Icons.schedule),
              label: 'Jadwal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Separate Dashboard Content Widget
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
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: isLoading
            ? const LoadingWidget(message: 'Memuat data...')
            : RefreshIndicator(
                onRefresh: () async => onRefresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(context),
                      Padding(
                        padding: const EdgeInsets.all(
                          AppConstants.paddingMedium,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTodayScheduleCard(),
                            const SizedBox(height: AppConstants.paddingMedium),
                            _buildMonthlyStats(),
                            const SizedBox(height: AppConstants.paddingMedium),
                            _buildQuickActions(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final karyawan = userData?['karyawan'] ?? {};
    final name = karyawan['full_name'] ?? 'User';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat datang!',
                        style: AppConstants.bodyStyle.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: AppConstants.titleStyle.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      ),
                      Text(
                        karyawan['nip'] ?? '',
                        style: AppConstants.captionStyle.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayScheduleCard() {
    final todayJadwal = dashboardData?['today']?['jadwal'];
    final todayAbsen = dashboardData?['today']?['absen'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppConstants.primaryColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.today, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Jadwal Hari Ini', style: AppConstants.subtitleStyle),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),

            if (todayJadwal != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.work,
                          size: 18,
                          color: AppConstants.successColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          todayJadwal['shift']['name'] ?? '',
                          style: AppConstants.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: AppConstants.successColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${todayJadwal['shift']['start_time']} - ${todayJadwal['shift']['end_time']}',
                          style: AppConstants.bodyStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (todayAbsen != null) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                _buildStatusBadge(todayAbsen['status']),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: AppConstants.textSecondaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada jadwal hari ini',
                      style: AppConstants.bodyStyle.copyWith(
                        color: AppConstants.textSecondaryColor,
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

  Widget _buildStatusBadge(String? status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'present':
        color = AppConstants.successColor;
        text = 'Hadir';
        icon = Icons.check_circle;
        break;
      case 'late':
        color = AppConstants.warningColor;
        text = 'Terlambat';
        icon = Icons.schedule;
        break;
      case 'absent':
        color = AppConstants.errorColor;
        text = 'Tidak Hadir';
        icon = Icons.cancel;
        break;
      case 'scheduled':
        color = AppConstants.textSecondaryColor;
        text = 'Belum Absen';
        icon = Icons.pending;
        break;
      default:
        color = AppConstants.textSecondaryColor;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats() {
    final stats = dashboardData?['monthly_stats'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statistik Bulan Ini', style: AppConstants.subtitleStyle),
        const SizedBox(height: AppConstants.paddingMedium),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppConstants.paddingMedium,
          mainAxisSpacing: AppConstants.paddingMedium,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Jadwal',
              '${stats['total_jadwal'] ?? 0}',
              Icons.calendar_today,
              AppConstants.primaryColor,
            ),
            _buildStatCard(
              'Hadir',
              '${stats['hadir'] ?? 0}',
              Icons.check_circle,
              AppConstants.successColor,
            ),
            _buildStatCard(
              'Terlambat',
              '${stats['terlambat'] ?? 0}',
              Icons.schedule,
              AppConstants.warningColor,
            ),
            _buildStatCard(
              'Tidak Hadir',
              '${stats['tidak_hadir'] ?? 0}',
              Icons.cancel,
              AppConstants.errorColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppConstants.titleStyle.copyWith(
                color: color,
                fontSize: 20,
              ),
            ),
            Text(
              label,
              style: AppConstants.captionStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Ganti method _buildQuickActions di _DashboardContent widget

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Menu Cepat', style: AppConstants.subtitleStyle),
        const SizedBox(height: AppConstants.paddingMedium),

        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildHorizontalActionCard(
                'Absen Sekarang',
                Icons.fingerprint,
                AppConstants.primaryColor,
                () {
                  final dashboardState = context
                      .findAncestorStateOfType<_DashboardScreenState>();
                  dashboardState?.setState(() {
                    dashboardState._selectedIndex = 1;
                  });
                },
              ),
              _buildHorizontalActionCard(
                'Lihat Jadwal',
                Icons.schedule,
                AppConstants.successColor,
                () {
                  final dashboardState = context
                      .findAncestorStateOfType<_DashboardScreenState>();
                  dashboardState?.setState(() {
                    dashboardState._selectedIndex = 2;
                  });
                },
              ),
              _buildHorizontalActionCard(
                'Lembur',
                Icons.work_history,
                AppConstants.warningColor,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LemburScreen()),
                  );
                },
              ),
              _buildHorizontalActionCard(
                'Tunjangan',
                Icons.payments,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TunjanganScreen()),
                  );
                },
              ),
             ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: AppConstants.bodyStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  
}
