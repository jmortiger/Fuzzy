import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';
import 'package:video_player/video_player.dart';
import 'package:fuzzy/log_management.dart' as lm;

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

/// TODO: Remove FutureBuilder, handle directly
class _WVideoPlayerScreenState extends State<WVideoPlayerScreen>
    with TickerProviderStateMixin {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WVideoPlayerScreen").logger;
  static const fadeInTime = Duration(milliseconds: 750);
  static const waitTime = Duration(seconds: 2);
  late AnimationController _fadeInController;
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  double volumeLastNonZeroValue = 1;
  bool showControlsRequest = false;
  bool isHoveringInRootInkWell = false;
  bool isHoveringInControlsInkWell = false;
  double get volume => _controller.value.volume;
  set volume(double v) => setState(() {
        _controller.setVolume(v);
      });

  bool get isVolumeOn => volume > 0;
  bool get showControls =>
      // showControlsRequest ||
      !_controller.value.isPlaying ||
      isHoveringInRootInkWell ||
      isHoveringInControlsInkWell;
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

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      vsync: this,
      duration: fadeInTime,
    );
    _controller = VideoPlayerController.networkUrl(
      widget.resourceUri,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: PostView.i.startVideoMuted,
      ),
      // httpHeaders: ,
    );

    _initializeVideoPlayerFuture = _controller.initialize();
    _controller.setLooping(true);

    widget.onRequestTogglePlayState + togglePlayState;
    if (PostView.i.autoplayVideo) {
      // TODO: Await until on screen
      // _initializeVideoPlayerFuture.then((v) => _controller.play());
    }
    volume = PostView.i.startVideoMuted ? 0 : 1;
    _controller.setVolume(volume);
    _controller.addListener(listener);
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

  bool isBuffering = false;
  void listener() {
    if (_controller.value.isBuffering != isBuffering) {
      setState(() {
        isBuffering = _controller.value.isBuffering;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showControls) {
      switch (_fadeInController.status) {
        case AnimationStatus.dismissed:
        case AnimationStatus.reverse:
          _fadeInController.forward().ignore();
          break;
        default:
          break;
      }
    } else {
      switch (_fadeInController.status) {
        case AnimationStatus.completed:
          Future.delayed(waitTime, () {
            if (_fadeInController.isCompleted && !showControls) {
              _fadeInController.reverse();
            }
          }).ignore();
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
                        togglePlayState();
                      },
                      onHover: (value) => setState(() {
                        isHoveringInRootInkWell = value;
                      }),
                    ),
                  ),
                  _buildBottomRowControls(),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _fadeInController,
                      builder: (context, child) {
                        return IgnorePointer(
                            ignoring: !_fadeInController.isDismissed,
                            child: Opacity(
                              opacity: _fadeInController.value,
                              child: child,
                            ));
                      },
                      child: IconButton(
                        iconSize: 24.0 * 2,
                        tooltip:
                            isVolumeOn ? "Turn off sound" : "Turn on sound",
                        onPressed: toggleMute,
                        icon: Icon(
                          volume != 0 ? Icons.volume_off : Icons.volume_up,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  Widget _buildBottomRowControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _fadeInController,
        builder: (context, child) {
          final root = Opacity(
            opacity: _fadeInController.value,
            child: Container(
              color: const Color.fromRGBO(0, 0, 0, .5),
              child: child,
            ),
          );
          return _fadeInController.status != AnimationStatus.dismissed
              ? root
              : IgnorePointer(child: root);
        },
        child: _buildNewControls(),
      ),
    );
  }

  final iconSize = 24.0 * 2;
  Widget _buildNewControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          flex: 100,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              IconButton(
                onPressed: togglePlayState,
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                iconSize: iconSize,
              ),
              WVideoTimeCodeUnit(controller: _controller),
              WVideoSpeed(height: iconSize, controller: _controller),
            ],
          ),
        ),
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
        ),
      ],
    );
  }
}

class WVideoSpeed extends StatelessWidget {
  const WVideoSpeed({
    super.key,
    required this.height,
    required VideoPlayerController controller,
  }) : _controller = controller;

  final double height;
  final VideoPlayerController _controller;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.only(right: 100),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox.fromSize(
            size: Size(
                calculateTextSize(
                  text: "0.000",
                  style: DefaultTextStyle.of(context).style,
                ).width,
                height),
            child: WNewSpeed(
              onValueChanged: (v) => _controller.setPlaybackSpeed(v),
            ),
          ),
        ),
      ),
    );
  }
}

class WNewSpeed extends StatefulWidget {
  const WNewSpeed({
    super.key,
    required this.onValueChanged,
  });
  final void Function(double) onValueChanged;

  @override
  State<WNewSpeed> createState() => _WNewSpeedState();
}

class _WNewSpeedState extends State<WNewSpeed> {
  @override
  void initState() {
    control = TextEditingController(text: "1.00")..addListener(listener);
    super.initState();
  }

  void listener() => widget.onValueChanged(double.parse(control.value.text));

  @override
  void dispose() {
    control
      ..removeListener(listener)
      ..dispose();
    super.dispose();
  }

  late TextEditingController control;
  @override
  Widget build(BuildContext context) {
    return DropdownMenu<double>(
      dropdownMenuEntries: const [
        DropdownMenuEntry(value: 0.25, label: "0.25"),
        DropdownMenuEntry(value: 0.50, label: "0.50"),
        DropdownMenuEntry(value: 0.75, label: "0.75"),
        DropdownMenuEntry(value: 1.00, label: "1.00"),
        DropdownMenuEntry(value: 1.25, label: "1.25"),
        DropdownMenuEntry(value: 1.50, label: "1.50"),
        DropdownMenuEntry(value: 1.75, label: "1.75"),
        DropdownMenuEntry(value: 2.00, label: "2.00"),
        DropdownMenuEntry(value: 2.25, label: "2.25"),
        DropdownMenuEntry(value: 2.50, label: "2.50"),
        DropdownMenuEntry(value: 2.75, label: "2.75"),
        DropdownMenuEntry(value: 3.00, label: "3.00"),
        DropdownMenuEntry(value: 3.25, label: "3.25"),
        DropdownMenuEntry(value: 3.50, label: "3.50"),
        DropdownMenuEntry(value: 3.75, label: "3.75"),
        DropdownMenuEntry(value: 4.00, label: "4.00"),
        DropdownMenuEntry(value: 4.25, label: "4.25"),
        DropdownMenuEntry(value: 4.50, label: "4.50"),
        DropdownMenuEntry(value: 4.75, label: "4.75"),
        DropdownMenuEntry(value: 5.00, label: "5.00"),
      ],
      initialSelection: 1,
      inputFormatters: [getParsableDecimalFormatter((p0) => p0 > 0)],
      controller: control,
    );
  }
}

class WVideoTimeCodeUnit extends StatefulWidget {
  final VideoPlayerController controller;
  const WVideoTimeCodeUnit({
    super.key,
    required this.controller,
  });

  @override
  State<WVideoTimeCodeUnit> createState() => _WVideoTimeCodeUnitState();
}

class _WVideoTimeCodeUnitState extends State<WVideoTimeCodeUnit> {
  bool showTimeLeft = PostView.i.showTimeLeft;
  Duration currTime = Duration.zero;
  Duration get trueCurrTime => widget.controller.value.position;
  void assignCurrTime() => setState(() {
        currTime = trueCurrTime;
      });
  Duration compareTime = Duration.zero;
  Duration get trueCompareTime => showTimeLeft
      ? widget.controller.value.duration - widget.controller.value.position
      : widget.controller.value.duration;
  void assignCompareTime() => setState(() {
        compareTime = trueCompareTime;
      });

  late final String durationString;
  @override
  void initState() {
    currTime = trueCurrTime;
    compareTime = trueCompareTime;
    durationString = widget.controller.value.duration
        .toFormattedString(fillZeros: false, discardMilliseconds: true);
    widget.controller.addListener(listener);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(listener);
    super.dispose();
  }

  void listener() {
    if (currTime.inSeconds != trueCurrTime.inSeconds) {
      assignCurrTime();
    }
    // Uncomment to allow dynamic changing of settings
    /* if (showTimeLeft != PostView.i.showTimeLeft) {
      setState(() {
        showTimeLeft = PostView.i.showTimeLeft;
        assignCompareTime();
      });
    } else  */
    if (showTimeLeft && compareTime.inSeconds != trueCompareTime.inSeconds) {
      assignCompareTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      "${currTime.toFormattedString(
        fillZeros: false,
        discardMilliseconds: true,
      )}/"
      "${showTimeLeft ? compareTime.toFormattedString(
          fillZeros: false,
          discardMilliseconds: true,
        ) : durationString}",
    );
  }
}
