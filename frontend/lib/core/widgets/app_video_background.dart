import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';

/// Decorative, muted video backdrop for wide authentication screens.
///
/// The video is treated as progressive enhancement:
/// * it never blocks the form from rendering,
/// * it is skipped when the platform has no video implementation,
/// * it is skipped when the user asks the system to reduce motion,
/// * playback pauses while the application is in the background,
/// * and a solid brand surface remains underneath as the fallback.
///
/// The content passed as [child] is always drawn above the video and its
/// contrast overlay, so no information depends on video support.
class AppVideoBackground extends StatefulWidget {
  const AppVideoBackground({
    super.key,
    required this.assetPath,
    required this.child,
    this.fallbackColor = AppColors.deepNavy,
    this.overlayOpacity = 0.58,
  });

  final String assetPath;
  final Widget child;
  final Color fallbackColor;
  final double overlayOpacity;

  @override
  State<AppVideoBackground> createState() => _AppVideoBackgroundState();
}

class _AppVideoBackgroundState extends State<AppVideoBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialiseIfAllowed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _initialiseIfAllowed() {
    if (_controller != null || _failed) return;

    final media = MediaQuery.maybeOf(context);
    final reduceMotion = media?.disableAnimations ?? false;

    // Video is an enhancement; do not spend resources when motion is reduced
    // or when running in a test harness that has no video plugin.
    final unsupportedDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);

    if (reduceMotion || unsupportedDesktop) {
      _failed = true;
      return;
    }

    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;

    unawaited(
      controller
          .initialize()
          .then((_) {
            if (!mounted || _controller != controller) return;
            unawaited(controller.setLooping(true));
            unawaited(controller.setVolume(0));
            unawaited(controller.play());
            setState(() => _ready = true);
          })
          .catchError((Object _) {
            // Missing plugin, unsupported codec or a blocked autoplay policy.
            // The brand surface and form remain fully usable.
            if (mounted) setState(() => _failed = true);
          }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showVideo = _ready && !_failed && controller != null;

    return ColoredBox(
      color: widget.fallbackColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (showVideo)
            ExcludeSemantics(
              child: RepaintBoundary(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          // A navy gradient keeps text readable over any frame while staying
          // recognisably part of the Deep Navy brand surface.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.deepNavy.withValues(
                    alpha: widget.overlayOpacity + 0.12,
                  ),
                  AppColors.deepNavy.withValues(alpha: widget.overlayOpacity),
                  AppColors.navyDeep.withValues(
                    alpha: widget.overlayOpacity + 0.18,
                  ),
                ],
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
