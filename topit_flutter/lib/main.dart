import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';

void main() => runApp(const TopitApp());

class TopitApp extends StatelessWidget {
  const TopitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Topit',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E8C61),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F2),
      ),
      home: HomeScreen(),
    );
  }
}
