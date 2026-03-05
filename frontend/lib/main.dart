import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('favorites');
  await Hive.openBox<String>('recents');
  runApp(const ProviderScope(child: NusMotionApp()));
}

class NusMotionApp extends StatelessWidget {
  const NusMotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NUS Motion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
