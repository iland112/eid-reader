import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/debug_log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In debug mode, start the on-screen + file logger so every log record
  // is written to a file AND kept in an in-memory buffer for the UI.
  if (kDebugMode) {
    await DebugLogService.instance.init();
  }

  runApp(
    const ProviderScope(
      child: EidReaderApp(),
    ),
  );
}
