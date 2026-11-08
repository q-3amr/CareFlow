import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'auth_wrapper.dart';
import 'services/database_service.dart'; // لحفظ الـ FCM Token عند تحديثه
//لعرض الإشعارات على شاشة الهاتف محلياً (خاصة عندما يكون التطبيق مفتوحاً).
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/common/chats_list_screen.dart';
import 'screens/common/schedule_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

//الدالة مكتوبة خارج main() ومسبوقة بـ @pragma('vm:entry-point') لكي يراها نظام التشغيل+
//وتعمل كبرنامج مستقل (Isolate) حتى لو التطبيق غير شغال. ولهذا السبب بالتحديد
//تم عمل Firebase.initializeApp() بداخلها مرة أخرى لأن سياق التطبيق الأساسي يكون مغلقاً
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // بتاكد انو ال background handler بيشتغل حتى لو التطبيق مش مفتوح
  await Firebase
      .initializeApp(); // لازم نعمل initialize عشان نقدر نتعامل مع ال Firebase في ال background
  debugPrint("Background notification received: ${message.messageId}");
  // لا نعرض الإشعار يدوياً هنا لأن Android/FCM يعرضه تلقائياً عندما يكون التطبيق في الخلفية أو مغلقاً
  // عرضه يدوياً هنا كان يسبب ظهوره مرتين
}

void handleNotificationNavigation(RemoteMessage message) {
  // دي function بتتعامل مع ال navigation لما يجي notification ونضغط عليه عشان نروح ل screen معين بناءً على نوع ال notification
  final type = message.data['type'];

  if (type == null) return;

  switch (type) {
    case 'chat':
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ChatsListScreen(),
        ),
      );
      break;

    case 'appointment':
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ScheduleScreen(
            isDoctor: false,
          ),
        ),
      );
      break;

    default:
      break;
  }
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0F14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>(
          create: (context) => ChatProvider(),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (context) => NotificationProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // Firebase init runs AFTER first frame so the splash shows immediately
  // instead of a black screen. UI stays responsive while it loads.
  unawaited(_initFirebaseAndNotifications());
}

Future<void> _initFirebaseAndNotifications() async {
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Ask for notification permission ONCE — skip if already authorized/denied.
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.getNotificationSettings();
  if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await DatabaseService().updateNotificationToken(uid);
      debugPrint('FCM Token refreshed and saved for user: $uid');
    }
  });

  var androidInitialize =
      const AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializeSetting =
      InitializationSettings(android: androidInitialize);

  await FlutterLocalNotificationsPlugin().initialize(
    initializeSetting,
    onDidReceiveNotificationResponse: (details) {},
  );

  FirebaseMessaging.onMessage.listen((event) async {
    if (event.notification != null) {
      BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
        event.notification!.body.toString(),
        htmlFormatBigText: true,
        contentTitle: event.notification!.title.toString(),
        htmlFormatContentTitle: true,
      );
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'CareFlow',
        'CareFlow',
        importance: Importance.high,
        playSound: true,
        styleInformation: bigTextStyleInformation,
        priority: Priority.high,
      );
      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      await FlutterLocalNotificationsPlugin().show(
        event.data.hashCode,
        event.notification?.title,
        event.notification?.body,
        platformChannelSpecifics,
        payload: event.data['body'],
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationNavigation);

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(
      const Duration(milliseconds: 500),
      () => handleNotificationNavigation(initialMessage),
    );
  }

  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ← مطلوب للتنقل عند الضغط على الإشعارات
      debugShowCheckedModeBanner: false,
      title: 'CareFlow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const AuthWrapper(),
    );
  }
}
