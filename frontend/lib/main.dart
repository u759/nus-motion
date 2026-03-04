import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/core/storage/local_storage.dart';
import 'package:frontend/state/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localStorage = LocalStorage();
  await localStorage.init();

  runApp(
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(localStorage)],
      child: const App(),
    ),
  );
}
