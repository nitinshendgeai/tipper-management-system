import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on mobile; web/desktop can resize freely.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const TipperERPApp());
}

class TipperERPApp extends StatelessWidget {
  const TipperERPApp({super.key});

  // Phase 4 (FE-004): Global navigator key passed to DioClient so the
  // 401 interceptor can redirect to login without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Wire the key into the shared Dio client on first build
    DioClient.navigatorKey = TipperERPApp.navigatorKey;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tipper ERP — Fleet Management',
      theme: AppTheme.light,
      navigatorKey: TipperERPApp.navigatorKey,
      home: const LoginScreen(),
    );
  }
}
