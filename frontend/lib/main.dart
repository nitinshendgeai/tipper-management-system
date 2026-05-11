import 'package:flutter/material.dart';

import 'modules/auth/screens/login_screen.dart';

void main() {
  runApp(const TipperERPApp());
}

class TipperERPApp extends StatelessWidget {
  const TipperERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Tipper ERP',

      theme: ThemeData(primarySwatch: Colors.blue),

      home: const LoginScreen(),
    );
  }
}
