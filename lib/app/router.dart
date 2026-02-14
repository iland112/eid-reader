import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/mrz_input/domain/entities/mrz_data.dart';
import '../features/mrz_input/presentation/screens/mrz_input_screen.dart';
import '../features/passport_reader/domain/entities/passport_data.dart';
import '../features/passport_reader/presentation/screens/nfc_scan_screen.dart';
import '../features/passport_display/presentation/screens/passport_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/mrz-input',
    routes: [
      GoRoute(
        path: '/mrz-input',
        name: 'mrz-input',
        builder: (context, state) => const MrzInputScreen(),
      ),
      GoRoute(
        path: '/nfc-scan',
        name: 'nfc-scan',
        builder: (context, state) {
          final mrzData = state.extra as MrzData;
          return NfcScanScreen(mrzData: mrzData);
        },
      ),
      GoRoute(
        path: '/passport-detail',
        name: 'passport-detail',
        builder: (context, state) {
          final passportData = state.extra as PassportData;
          return PassportDetailScreen(passportData: passportData);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
