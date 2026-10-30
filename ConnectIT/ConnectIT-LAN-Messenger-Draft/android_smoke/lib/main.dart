import 'package:flutter/material.dart';

import 'device_access_page.dart';

export 'device_access_page.dart' show ConnectITMasterSetupPage;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConnectITAcceptanceApp());
}

class ConnectITAcceptanceApp extends StatelessWidget {
  const ConnectITAcceptanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF090F1D);
    const blue = Color(0xFF72B2FF);
    return MaterialApp(
      title: 'ConnectIT development',
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
          surface: const Color(0xFF101C31),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      home: const ConnectITMasterSetupPage(),
    );
  }
}
