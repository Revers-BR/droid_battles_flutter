import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const DroidBattlesApp());
}

class DroidBattlesApp extends StatelessWidget {
  const DroidBattlesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Droid Battles',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
