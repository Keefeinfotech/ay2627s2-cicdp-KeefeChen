import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';

/// Desktop/Web layout with split form (left) and brand panel (right).
/// Mobile devices collapse down to a single scrollable form.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final bool canPop = showBack ?? (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    // Left Form Panel
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                          vertical: AppSpacing.xl,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: _AuthForm(
                              title: title,
                              subtitle: subtitle,
                              canPop: canPop,
                              footer: footer,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right Graphic/Video Panel
                    const Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                        child: _AuthBrandPanel(),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile view (Single column centered form)
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                canPop ? AppSpacing.xs : AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _AuthForm(
                    title: title,
                    subtitle: subtitle,
                    canPop: canPop,
                    footer: footer,
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.title,
    required this.subtitle,
    required this.canPop,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final bool canPop;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        const BrandLockup(markSize: 28),
        const SizedBox(height: AppSpacing.xxxl),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.xxl),
        child,
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.xl),
          footer!,
        ],
      ],
    );
  }
}

class _AuthBrandPanel extends StatefulWidget {
  const _AuthBrandPanel();

  @override
  State<_AuthBrandPanel> createState() => _AuthBrandPanelState();
}

class _AuthBrandPanelState extends State<_AuthBrandPanel> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/auth_bg.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.setVolume(0.0);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_controller.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          )
        else
          const ColoredBox(color: AppColors.deepNavy),
      ],
    );
  }
}
