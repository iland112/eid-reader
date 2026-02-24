import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/device_capability_provider.dart';
import '../../../../app/locale_provider.dart';
import '../../../../app/theme_mode_provider.dart';
import '../../../../core/utils/l10n_extension.dart';

/// Landing / welcome screen shown on first app launch.
///
/// Displays branding, feature highlights, and a prominent
/// "Get Started" button that navigates to the MRZ input screen.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Stagger intervals (within 1200ms total)
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _featuresFade;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;
  late final Animation<double> _settingsFade;
  late final Animation<double> _copyrightFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.17, 0.58, curve: Curves.easeOut),
    );
    _titleSlide = Tween(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_titleFade);

    _featuresFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.33, 0.75, curve: Curves.easeOut),
    );

    _buttonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.83, curve: Curves.easeOut),
    );
    _buttonSlide = Tween(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(_buttonFade);

    _settingsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.92, curve: Curves.easeOut),
    );

    _copyrightFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.58, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: l10n.semanticLandingScreen,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Logo (passport + shield + e-passport chip)
                    ScaleTransition(
                      scale: _logoScale,
                      child: Semantics(
                        label: l10n.semanticLandingLogo,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Passport book background
                              Icon(
                                Icons.menu_book,
                                size: 88,
                                color: colorScheme.primary
                                    .withValues(alpha: 0.3),
                              ),
                              // Shield overlay
                              Icon(
                                Icons.shield,
                                size: 64,
                                color: colorScheme.primary,
                              ),
                              // NFC chip badge (bottom-right)
                              Positioned(
                                right: 20,
                                bottom: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.contactless,
                                    size: 24,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Text(
                          l10n.appTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Feature chips (capability-aware)
                    FadeTransition(
                      opacity: _featuresFade,
                      child: Builder(builder: (context) {
                        final capAsync =
                            ref.watch(chipReaderCapabilityProvider);
                        final hasChip = capAsync.whenOrNull(
                                data: (cap) => hasChipReader(cap)) ??
                            false;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (hasChip) ...[
                              _FeatureChip(
                                icon: Icons.nfc,
                                label: l10n.landingFeatureNfc,
                              ),
                              _FeatureChip(
                                icon: Icons.verified_user,
                                label: l10n.landingFeatureSecurity,
                              ),
                            ],
                            _FeatureChip(
                              icon: Icons.document_scanner,
                              label: l10n.landingFeatureOcr,
                            ),
                          ],
                        );
                      }),
                    ),

                    const SizedBox(height: 40),

                    // CTA button
                    FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: FilledButton.icon(
                          onPressed: () => context.go('/mrz-input'),
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(l10n.landingButtonStart),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Settings row (locale + theme toggle)
                    FadeTransition(
                      opacity: _settingsFade,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.language),
                            tooltip: l10n.mrzInputTooltipSwitchLang,
                            onPressed: () =>
                                ref.read(localeProvider.notifier).toggle(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                            ),
                            tooltip:
                                Theme.of(context).brightness == Brightness.dark
                                    ? l10n.mrzInputTooltipLightMode
                                    : l10n.mrzInputTooltipDarkMode,
                            onPressed: () =>
                                ref.read(themeModeProvider.notifier).toggle(),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Copyright
                    FadeTransition(
                      opacity: _copyrightFade,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copyright,
                            size: 14,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'SmartCore Inc. All rights reserved.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
