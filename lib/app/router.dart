import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/mrz_input/domain/entities/mrz_data.dart';
import '../features/mrz_input/presentation/screens/mrz_camera_screen.dart';
import '../features/mrz_input/presentation/screens/mrz_input_screen.dart';
import '../features/passport_reader/data/datasources/passport_datasource_factory.dart';
import '../features/passport_reader/domain/entities/passport_data.dart';
import '../features/passport_reader/presentation/screens/nfc_scan_screen.dart';
import '../features/passport_reader/presentation/screens/pcsc_scan_screen.dart';
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
        path: '/mrz-camera',
        name: 'mrz-camera',
        builder: (context, state) => const MrzCameraScreen(),
      ),
      GoRoute(
        path: '/scan',
        name: 'scan',
        pageBuilder: (context, state) {
          final mrzData = state.extra as MrzData;

          // Platform-adaptive scan screen
          final scanScreen = PassportDatasourceFactory.isNfcPlatform
              ? NfcScanScreen(mrzData: mrzData)
              : PcscScanScreen(mrzData: mrzData);

          return CustomTransitionPage(
            key: state.pageKey,
            child: scanScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final slideTween = Tween(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOut));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(slideTween),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      GoRoute(
        path: '/passport-detail',
        name: 'passport-detail',
        pageBuilder: (context, state) {
          final passportData = state.extra as PassportData;
          return CustomTransitionPage(
            key: state.pageKey,
            child: PassportDetailScreen(passportData: passportData),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          );
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
