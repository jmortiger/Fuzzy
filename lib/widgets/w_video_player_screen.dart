import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/events.dart';
import 'package:video_player/video_player.dart';

class WVideoPlayerScreen extends StatefulWidget {
  final Uri resourceUri;
  final JPureEvent onRequestTogglePlayState = JPureEvent();

  WVideoPlayerScreen({
    super.key,
    required this.resourceUri,
  });

  @override
  State<WVideoPlayerScreen> createState() => _WVideoPlayerScreenState();
}

class _WVideoPlayerScreenState extends State<WVideoPlayerScreen>
    with TickerProviderStateMixin {
  static const fadeInTime = Duration(seconds: 2);
  late AnimationController _fadeInController;
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  double volumeLastNonZeroValue = 1;
  double get volume => _controller.value.volume;
  set volume(double v) => setState(() {
        _controller.setVolume(v);
      });
  double setVolume([double level = 1]) {
    if (level >= 0 && level <= 1) {
      setState(() {
        volume = level;
        if (level != 0) {
          volumeLastNonZeroValue = level;
        }
      });
    }
    return volume;
  }

  bool toggleMute() {
    setState(() {
      volume = isVolumeOn ? 0 : volumeLastNonZeroValue;
    });
    return isVolumeOn;
  }

  bool get isVolumeOn => volume > 0;
  bool get showControls =>
      showControlsRequest ||
      isHoveringInRootInkWell ||
      isHoveringInControlsInkWell;
  bool showControlsRequest = false;
  bool isHoveringInRootInkWell = false;
  bool isHoveringInControlsInkWell = false;

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      vsync: this,
      duration: fadeInTime,
    );

    // Create and store the VideoPlayerController. The VideoPlayerController
    // offers several different constructors to play videos from assets, files,
    // or the internet.
    _controller = VideoPlayerController.networkUrl(
      widget.resourceUri,
      // httpHeaders: ,
    );

    _initializeVideoPlayerFuture = _controller.initialize();
    _controller.setLooping(true);

    widget.onRequestTogglePlayState + togglePlayState;
    if (PostView.i.autoplayVideo) {
      _initializeVideoPlayerFuture.then((v) => _controller.play());
    }
    volume = PostView.i.startVideoMuted ? 0 : 1;
    _controller.setVolume(volume);
  }

  void togglePlayState() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        showControlsRequest = true;
      } else {
        _controller.play();
        showControlsRequest = false;
      }
    });
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (showControls) {
      switch (_fadeInController.status) {
        case AnimationStatus.dismissed:
        case AnimationStatus.reverse:
          _fadeInController.forward();
          break;
        default:
          break;
      }
    } else {
      switch (_fadeInController.status) {
        case AnimationStatus.completed:
        case AnimationStatus.forward:
          _fadeInController.reverse();
          break;
        default:
          break;
      }
    }
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the VideoPlayerController has finished initialization, use
          // the data it provides to limit the aspect ratio of the video.
          return AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VideoPlayer(_controller),
                  ),
                  Positioned.fill(
                    child: InkWell(
                      onTap: () {
                        print("LowerInkWell onTap");
                        togglePlayState();
                      },
                      onHover: (value) => setState(() {
                        isHoveringInRootInkWell = value;
                      }),
                    ),
                  ),
                  if (_fadeInController.status != AnimationStatus.dismissed)
                    _buildBottomRowControls(),
                  if (_fadeInController.status != AnimationStatus.dismissed)
                    Positioned.directional(
                      textDirection: TextDirection.ltr,
                      top: 0,
                      end: 0,
                      child: IconButton(
                        tooltip:
                            isVolumeOn ? "Turn off sound" : "Turn on sound",
                        onPressed: () => setState(() {
                          volume = volume == 0 ? 1 : 0;
                        }),
                        icon: Icon(
                          volume != 0 ? Icons.volume_off : Icons.volume_up,
                        ),
                      ),
                    ),
                  // Positioned.fill(
                  //   child: InkWell(
                  //     onHover: (value) => setState(() {
                  //       print("HigherInkWell onHover");
                  //       showControls = value;
                  //     }),
                  //   ),
                  // ),
                ],
              ),
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

  Widget _buildBottomRowControls() {
    // print("showControls");
    return Positioned.directional(
      bottom: 0,
      start: 0,
      end: 0,
      textDirection: TextDirection.ltr,
      child: InkWell(
        hoverColor: Colors.black,
        onHover: (value) => setState(() {
          isHoveringInControlsInkWell = value;
          print("isHoveringInControlsInkWell: $value");
        }),
        child: Row(
          // mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              onPressed: togglePlayState,
              icon: const Icon(Icons.play_arrow),
            ),
            Text(_controller.value.position.toString()),
            WTimeline(controller: _controller),
            Text(
              (PostView.i.showTimeLeft
                      ? _controller.value.duration - _controller.value.position
                      : _controller.value.duration)
                  .toString(),
            ),
            SizedBox.shrink(
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: TextEditingController(text: "1.00"),
                maxLength: 4,
                maxLines: 1,
                inputFormatters: [numericFormatter],
                onChanged: (value) => num.tryParse(value)?.isFinite ?? false
                    ? _controller.setPlaybackSpeed(
                        num.parse(value).abs().toDouble(),
                      )
                    : "",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TODO: Make interactive
class WTimeline extends StatefulWidget {
  const WTimeline({
    super.key,
    required VideoPlayerController controller,
  }) : _controller = controller;

  final VideoPlayerController _controller;

  @override
  State<WTimeline> createState() => _WTimelineState();
}

class _WTimelineState extends State<WTimeline> {
  double value = 0;
  @override
  void initState() {
    super.initState();
    value = widget._controller.value.position.inMilliseconds /
        widget._controller.value.duration.inMilliseconds;
    widget._controller.addListener(onValueChanged);
  }

  void onValueChanged() {
    double t;
    if ((t = widget._controller.value.position.inMilliseconds /
            widget._controller.value.duration.inMilliseconds) !=
        value) {
      setState(() {
        value = t;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LinearProgressIndicator(
        value: value,
      ),
    );
  }
}
