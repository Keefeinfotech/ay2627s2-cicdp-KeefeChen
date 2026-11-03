import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoBackground extends StatefulWidget {
  final Widget child;
  final String assetPath;
  final double overlayOpacity;

  const VideoBackground({
    super.key,
    required this.child,
    required this.assetPath,
    this.overlayOpacity = 0.45,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.setVolume(0.0); // Mute for web autoplay policy compliance
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
        // Video layer
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
          Container(color: Theme.of(context).colorScheme.primary),

        // Semi-transparent overlay to ensure text readability
        Container(
          color: Colors.black.withOpacity(widget.overlayOpacity),
        ),

        // Text & Branding content layer
        widget.child,
      ],
    );
  }
}