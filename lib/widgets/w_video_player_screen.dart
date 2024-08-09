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

class _WVideoPlayerScreenState extends State<WVideoPlayerScreen>
    with TickerProviderStateMixin {
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WVideoPlayerScreen");
  // #endregion Logger
  static const fadeInTime = Duration(milliseconds: 750);
  late AnimationController _fadeInController;
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  double volumeLastNonZeroValue = 1;
  bool showControlsRequest = false;
  bool isHoveringInRootInkWell = false;
  bool isHoveringInControlsInkWell = false;
  // late Animation<Color?> colorAnim;
  double get volume => _controller.value.volume;
  set volume(double v) => setState(() {
        _controller.setVolume(v);
      });

  bool get isVolumeOn => volume > 0;
  bool get showControls =>
      showControlsRequest ||
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
    // var colorTween = ColorTween(
    //     begin: const Color.fromRGBO(0, 0, 0, 0),
    //     end: const Color.fromRGBO(0, 0, 0, 1));
    // var middleMan = Tween<double>(begin: 1,end:  0);
    // colorAnim = colorTween.animate(_fadeInController.drive(middleMan));
    _controller = VideoPlayerController.networkUrl(
      widget.resourceUri,
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
                        logger.fine("LowerInkWell onTap");
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
                        iconSize: 24.0 * 2,
                        tooltip:
                            isVolumeOn ? "Turn off sound" : "Turn on sound",
                        onPressed: toggleMute,
                        icon: Icon(
                          volume != 0 ? Icons.volume_off : Icons.volume_up,
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
    // print("showControls");
    return Positioned.directional(
      bottom: 0,
      start: 0,
      end: 0,
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color.fromRGBO(0, 0, 0, .5), //colorAnim.value,
        child: InkWell(
          // hoverColor: colorAnim.value,
          onHover: (value) => setState(() {
            isHoveringInControlsInkWell = value;
            logger.fine("isHoveringInControlsInkWell: $value");
          }),
          child: _buildNewControls(),
        ),
      ),
    );
  }

  /* Row _buildOldControls() {
    return Row(
      // mainAxisSize: MainAxisSize.max,
      children: [
        IconButton(
          onPressed: togglePlayState,
          icon: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
          iconSize: 24.0 * 2,
        ),
        Text(
          _controller.value.position.toFormattedString(fillZeros: false),
        ),
        WTimeline(controller: _controller),
        Text(
          (PostView.i.showTimeLeft
                  ? _controller.value.duration - _controller.value.position
                  : _controller.value.duration)
              .toFormattedString(fillZeros: false),
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
    );
  } */

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
              WVideoTimeCodeUnit(
                controller: _controller,
              ),
              WVideoSpeed(height: iconSize, controller: _controller),
              // WVideoSpeedOld(height: iconSize, controller: _controller),
            ],
          ),
        ),
        WTimeline(
          controller: _controller,
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

// TODO: Improve scrubbing
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
  set position(Duration value) => widget._controller.seekTo(value);
  Duration get position => widget._controller.value.position;
  Duration get duration => widget._controller.value.duration;
  double value = 0;
  @override
  void initState() {
    super.initState();
    value = widget._controller.value.position.inMilliseconds /
        widget._controller.value.duration.inMilliseconds;
    widget._controller.addListener(onValueChanged);
  }

  @override
  void dispose() {
    widget._controller.removeListener(onValueChanged);
    super.dispose();
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

  bool? cachedPlayState;
  // bool? seeking;
  Future<void>? seekFuture;
  @override
  Widget build(BuildContext context) {
    return Flexible(
      fit: FlexFit.loose,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Slider(
          onChangeStart: (value) {
            widget._controller.removeListener(onValueChanged);
            setState(() {
              cachedPlayState = widget._controller.value.isPlaying;
            });
          },
          onChanged: (value) {
            // setState(() {
            //   seeking = true;
            // });
            setState(() {
              seekFuture = widget._controller.seekTo(duration * value)
                ..then((d) => setState(() {
                      //seeking = false;
                      seekFuture = null;
                    }));
            });
          },
          onChangeEnd: (value) {
            if (cachedPlayState ?? false) {
              if (seekFuture == null) {
                widget._controller.play();
              } else {
                seekFuture!.then((v) => widget._controller.play());
              }
            }
            setState(() {
              cachedPlayState = null;
            });
            widget._controller.addListener(onValueChanged);
          },
          value: value,
        ),
        // child: LinearProgressIndicator(
        //   value: value,
        // ),
      ),
    );
  }
}
