// ignore_for_file: implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

/// Call this in [setUpAll] of every test file that mounts any widget
/// depending on Firebase (Auth, Firestore, etc.).
///
/// It registers a mock [TestFirebaseCoreHostApi] backed by fake options and
/// then eagerly calls [Firebase.initializeApp] so the `[DEFAULT]` app exists
/// before any widget is pumped.
Future<void> setupFirebaseMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Register the mock Pigeon host API used by firebase_core 3.x
  TestFirebaseCoreHostApi.setUp(_MockFirebaseCoreApi());

  // Initialize the default Firebase app using the mocked channel
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: '1:000000000000:android:abcdef',
      messagingSenderId: '000000000000',
      projectId: 'fake-project',
    ),
  );
}

/// Minimal in-memory implementation of [TestFirebaseCoreHostApi].
class _MockFirebaseCoreApi implements TestFirebaseCoreHostApi {
  static CoreFirebaseOptions get _fakeOptions => CoreFirebaseOptions(
        apiKey: 'fake-api-key',
        appId: '1:000000000000:android:abcdef',
        messagingSenderId: '000000000000',
        projectId: 'fake-project',
      );

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: _fakeOptions,
      pluginConstants: {},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return [
      CoreInitializeResponse(
        name: defaultFirebaseAppName,
        options: _fakeOptions,
        pluginConstants: {},
      ),
    ];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async => _fakeOptions;
}
