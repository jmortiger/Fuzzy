// import 'package:flutter/material.dart';

// // #region Logger
// import 'package:fuzzy/log_management.dart' as lm;

// late final lRecord = lm.genLogger("WProgressiveImage");
// late final print = lRecord.print;
// late final logger = lRecord.logger;
// // #endregion Logger
// typedef ImageConfig = ({
//   ImageProvider provider,
//   ImageConfiguration config,
// });
// typedef ImageConfigBuilder = ImageConfig? Function(
//   BuildContext cxt,
//   int index,
// );
// typedef ImageConfigBoundedBuilder = ImageConfig Function(
//   BuildContext cxt,
//   int index,
// );

// /// TODO: EVERYTHING
// class WProgressiveImage extends StatefulWidget {
//   final int fallbackIndex;

//   const WProgressiveImage._({
//     super.key,
//     required this.orderedImageAndConfigs,
//     required this.builder,
//     required int? expectedCount,
//     required this.fallbackIndex,
//   }) : _expectedCount = expectedCount;
//   const WProgressiveImage.builder({
//     Key? key,
//     required ImageConfigBuilder builder,
//     int? expectedCount,
//     int fallbackIndex = -1,
//   }) : this._(
//           key: key,
//           builder: builder,
//           expectedCount: expectedCount,
//           orderedImageAndConfigs: null,
//           fallbackIndex: fallbackIndex,
//         );
//   const WProgressiveImage.list({
//     Key? key,
//     required List<ImageConfig> orderedImageAndConfigs,
//     int fallbackIndex = -1,
//   }) : this._(
//           key: key,
//           builder: null,
//           expectedCount: null,
//           orderedImageAndConfigs: orderedImageAndConfigs,
//           fallbackIndex: fallbackIndex,
//         );
//   final List<ImageConfig>? orderedImageAndConfigs;
//   final ImageConfigBuilder? builder;
//   final int? _expectedCount;
//   int get expectedCount =>
//       _expectedCount ?? orderedImageAndConfigs?.length ?? -1;
//   @override
//   State<WProgressiveImage> createState() => _WProgressiveImageState();
// }

// class _WProgressiveImageState extends State<WProgressiveImage> {
//   bool get useBuilder => widget.builder != null;
//   bool get useList => widget.orderedImageAndConfigs != null;
//   final List<ImageConfig> _myList = [];
//   List<ImageConfig> get myList => widget.orderedImageAndConfigs ?? _myList;
//   List<ImageConfig>? get list => widget.orderedImageAndConfigs;
//   ImageConfigBuilder? get builder => widget.builder;
//   Image? 

//   @override
//   void initState() {
//     super.initState();
//     streams = [];
//     ImageConfig? e;
//     for (var i = 0;
//         (e = useBuilder
//                 ? builder?.call(context, i)
//                 : list!.elementAtOrNull(i)) !=
//             null;
//         i++) {
//       final temp = e!.provider..resolve(e.config);
//       Image
//       streams.add(temp);
//       temp.completer?.addListener(
//         MyListener(
//           getOnImageLoaded(i, e),
//           onChunk: getOnChunk(i, e),
//           onError: getOnError(i, e),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext ctx) {
//     myList.first.config.
//     // TODO: implement build
//     throw UnimplementedError();
//   }

// }
// /* class _WProgressiveImageState extends State<WProgressiveImage> {
//   bool get useBuilder => widget.builder != null;
//   bool get useList => widget.orderedImageAndConfigs != null;
//   final List<ImageConfig> _myList = [];
//   List<ImageConfig> get myList => widget.orderedImageAndConfigs ?? _myList;
//   List<ImageConfig>? get list => widget.orderedImageAndConfigs;
//   ImageConfigBuilder? get builder => widget.builder;
//   List<ImageStream> streams = [];
//   ImageInfo? currentImage;

//   @override
//   void initState() {
//     super.initState();
//     streams = [];
//     ImageConfig? e;
//     for (var i = 0;
//         (e = useBuilder
//                 ? builder?.call(context, i)
//                 : list!.elementAtOrNull(i)) !=
//             null;
//         i++) {
//       final temp = e!.provider..resolve(e.config);
//       Image
//       streams.add(temp);
//       temp.completer?.addListener(
//         MyListener(
//           getOnImageLoaded(i, e),
//           onChunk: getOnChunk(i, e),
//           onError: getOnError(i, e),
//         ),
//       );
//     }
//   }

//   ImageListener getOnImageLoaded(int index, ImageConfig config) =>
//       (ImageInfo image, bool synchronousCall) {
//         if (i == 0) {

//         }
//       };
//   ImageChunkListener getOnChunk(int index, ImageConfig config) =>
//       (ImageChunkEvent event) {};
//   void Function(
//     Object exception,
//     StackTrace? stackTrace,
//   ) getOnError(int index, ImageConfig config) => (
//         Object exception,
//         StackTrace? stackTrace,
//       ) =>
//           logger.severe(exception, exception, stackTrace);

//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }
// } */

// class MyListener extends ImageStreamListener {
//   const MyListener(super.onImage, {super.onChunk, super.onError});
// }