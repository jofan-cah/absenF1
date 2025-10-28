// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

// ============================================
// LOCAL NOTIFICATIONS PLUGIN (HARUS DI ATAS!)
// ============================================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ CHANNEL DENGAN IMPORTANCE MAX
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Channel untuk notifikasi penting',
  importance: Importance.max,      // ✅ UBAH JADI MAX!
  playSound: true,                 // ✅ TAMBAH
  enableVibration: true,           // ✅ TAMBAH
  showBadge: true,                 // ✅ TAMBAH
);

// ============================================
// BACKGROUND MESSAGE HANDLER (WAJIB TOP-LEVEL)
// ============================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔔 Background message: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  
  // ✅ HAPUS SHOW NOTIFICATION DI SINI (biar gak dobel)
  // Backend udah kirim notification payload, jadi otomatis muncul
  // Kalau tetep dobel, berarti backend kirim notification + kita manual show lagi
}

// ✅ FUNCTION SHOW NOTIFICATION (DI TOP-LEVEL JUGA!)
Future<void> showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'Channel untuk notifikasi penting',
    importance: Importance.max,     // ✅ MAX
    priority: Priority.max,         // ✅ UBAH JADI MAX!
    // icon: '@mipmap/ic_launcher',
     icon: '@drawable/ic_notification',
    playSound: true,
    enableVibration: true,
    showWhen: true,
     color: Color(0xFFE53935),  
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Notifikasi',
    message.notification?.body ?? '',
    notificationDetails,
    payload: message.data.toString(),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi format tanggal lokal Indonesia (id_ID)
  await initializeDateFormatting('id_ID', null);

  // ============================================
  // INITIALIZE FIREBASE
  // ============================================
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ============================================
  // SETUP LOCAL NOTIFICATIONS
  // ============================================
  await setupLocalNotifications();

  // ============================================
  // SETUP FCM
  // ============================================
  await setupFCM();

  runApp(const F1AbsensiApp());
}

// ============================================
// SETUP LOCAL NOTIFICATIONS
// ============================================
Future<void> setupLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@drawable/ic_notification');  // ✅ PAKAI INI

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('📱 Notification tapped: ${response.payload}');
      // TODO: Navigate ke halaman tertentu
    },
  );

  // ✅ Create notification channel dengan settings yang udah di-define di atas
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// ============================================
// SETUP FCM
// ============================================
Future<void> setupFCM() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission (iOS & Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('🔐 Permission status: ${settings.authorizationStatus}');

    // ✅ Get FCM Token dengan try-catch
    try {
      String? token = await messaging.getToken();
      if (token != null) {
        print('🔥 FCM Token: $token');
        print('⚠️  COPY TOKEN INI UNTUK TEST!');
        
        // TODO: Save token ke Laravel API setelah login
        // await saveTokenToServer(token);
      } else {
        print('⚠️  FCM Token is null');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      print('⚠️  App akan tetap jalan tanpa FCM token');
    }

    // Listen untuk token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 Token refreshed: $newToken');
      // TODO: Update token ke server
      // saveTokenToServer(newToken);
    });

    // ============================================
    // HANDLE FOREGROUND MESSAGES
    // ============================================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message received!');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      // ✅ Show local notification saat app di foreground
      if (message.notification != null) {
        showLocalNotification(message);
      }
    });

    // ============================================
    // HANDLE NOTIFICATION TAP (APP OPENED FROM NOTIFICATION)
    // ============================================
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification tapped!');
      print('Data: ${message.data}');

      // TODO: Navigate ke halaman tertentu berdasarkan data
      // Contoh:
      // if (message.data['type'] == 'reminder_clock_in') {
      //   Navigator.push(context, MaterialPageRoute(builder: (context) => AbsenScreen()));
      // }
    });

    // ============================================
    // CHECK INITIAL MESSAGE (APP OPENED FROM TERMINATED STATE)
    // ============================================
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App opened from notification (terminated state)');
      print('Data: ${initialMessage.data}');
      // TODO: Handle initial message
    }
  } catch (e) {
    print('❌ Error setting up FCM: $e');
    print('⚠️  App akan tetap jalan tanpa FCM');
  }
}

// ============================================
// F1 ABSENSI APP
// ============================================
class F1AbsensiApp extends StatelessWidget {
  const F1AbsensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'F1 Absensi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF2196F3),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}