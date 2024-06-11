import 'package:flutter/material.dart';
import 'package:j_util/events.dart';
import 'package:video_player/video_player.dart';

class WVideoPlayerScreen extends StatefulWidget {
  // final void Function()? onPlayerLoaded;
  // Uri.parse(
  //       'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
  //     ),
  final Uri resourceUri;

  final JPureEvent onRequestTogglePlayState = JPureEvent();

  WVideoPlayerScreen({
    super.key,
    /* this.onPlayerLoaded, */ required this.resourceUri,
  });

  @override
  State<WVideoPlayerScreen> createState() => _WVideoPlayerScreenState();
}

class _WVideoPlayerScreenState extends State<WVideoPlayerScreen> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();

    // Create and store the VideoPlayerController. The VideoPlayerController
    // offers several different constructors to play videos from assets, files,
    // or the internet.
    _controller = VideoPlayerController.networkUrl(widget.resourceUri);

    _initializeVideoPlayerFuture = _controller.initialize();
    // _initializeVideoPlayerFuture.then((_) => widget.onPlayerLoaded?.call());
    _controller.setLooping(true);

    widget.onRequestTogglePlayState + togglePlayState;
  }

  void togglePlayState() {
    setState(() {
      // If the video is playing, pause it.
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        // If the video is paused, play it.
        _controller.play();
      }
    });
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the VideoPlayerController has finished initialization, use
          // the data it provides to limit the aspect ratio of the video.
          return InkWell(
            onTap: () {
              print("onTap");
              togglePlayState();
            },
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              // Use the VideoPlayer widget to display the video.
              child: VideoPlayer(_controller),
            ),
          );
        } else {
          // If the VideoPlayerController is still initializing, show a
          // loading spinner.
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
