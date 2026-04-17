import 'package:flutter/material.dart';

import '../../core/design_system/foundations/star_kids_colors.dart';
import '../../core/design_system/foundations/star_kids_radii.dart';
import '../../core/design_system/foundations/star_kids_spacing.dart';
import '../../core/design_system/widgets/star_kids_button.dart';
import '../../core/design_system/widgets/star_kids_logo_loader.dart';
import '../app.dart';
import '../theme/app_theme.dart';

class StarKidsBootstrapApp extends StatefulWidget {
  const StarKidsBootstrapApp({
    super.key,
    required this.initialize,
  });

  final Future<void> Function() initialize;

  @override
  State<StarKidsBootstrapApp> createState() => _StarKidsBootstrapAppState();
}

class _StarKidsBootstrapAppState extends State<StarKidsBootstrapApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const StarKidsApp();
        }

        return MaterialApp(
          title: 'Star Kids',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: snapshot.hasError
              ? _BootstrapErrorView(
                  onRetry: () {
                    setState(() {
                      _initialization = widget.initialize();
                    });
                  },
                )
              : const _BootstrapLoadingView(),
        );
      },
    );
  }
}

class _BootstrapLoadingView extends StatelessWidget {
  const _BootstrapLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: StarKidsColors.surfaceCanvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(StarKidsSpacing.xl),
            child: StarKidsLogoLoader(),
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? StarKidsDarkColors.surfaceCanvas
          : StarKidsColors.surfaceCanvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(StarKidsSpacing.xl),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.all(StarKidsSpacing.xl),
              decoration: BoxDecoration(
                color: isDark
                    ? StarKidsDarkColors.surfaceElevated
                    : StarKidsColors.surfacePrimary,
                borderRadius: BorderRadius.circular(StarKidsRadii.xl),
                border: Border.all(
                  color: isDark
                      ? StarKidsDarkColors.borderDefault
                      : StarKidsColors.borderDefault,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 156,
                    height: 156,
                    child: StarKidsLogoLoader(),
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  Text(
                    'Не удалось открыть приложение',
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: StarKidsSpacing.sm),
                  Text(
                    'Попробуйте повторить загрузку. Маршруты не менялись, повторно запускается только инициализация приложения.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? StarKidsDarkColors.textSecondary
                          : StarKidsColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: StarKidsSpacing.lg),
                  StarKidsButton.primary(
                    label: 'Повторить',
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
