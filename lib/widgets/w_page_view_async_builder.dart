// import 'dart:async';

// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';

// class WPageViewAsyncBuilder extends StatefulWidget {
//   final Axis scrollDirection;
//   final bool reverse;
//   final PageController? controller;
//   final ScrollPhysics? physics;
//   final bool pageSnapping;
//   final void Function(int)? onPageChanged;
//   final FutureOr<Widget?>? Function(BuildContext, int) itemBuilder;
//   final int? Function(Key)? findChildIndexCallback;
//   final int? itemCount;
//   final DragStartBehavior dragStartBehavior;
//   final bool allowImplicitScrolling;
//   final String? restorationId;
//   final Clip clipBehavior;
//   final ScrollBehavior? scrollBehavior;
//   final bool padEnds;
//   const WPageViewAsyncBuilder.builder({
//     super.key,
//     this.scrollDirection = Axis.horizontal,
//     this.reverse = false,
//     this.controller,
//     this.physics,
//     this.pageSnapping = true,
//     this.onPageChanged,
//     required this.itemBuilder,
//     this.findChildIndexCallback,
//     this.itemCount,
//     this.dragStartBehavior = DragStartBehavior.start,
//     this.allowImplicitScrolling = false,
//     this.restorationId,
//     this.clipBehavior = Clip.hardEdge,
//     this.scrollBehavior,
//     this.padEnds = true,
//   });

//   @override
//   State<WPageViewAsyncBuilder> createState() => _WPageViewAsyncBuilderState();
// }

// class _WPageViewAsyncBuilderState extends State<WPageViewAsyncBuilder> {
//   @override
//   Widget build(BuildContext context) {
//     return PageView.builder(
//       scrollDirection: widget.scrollDirection,
//       reverse: widget.reverse,
//       controller: widget.controller,
//       physics: widget.physics,
//       pageSnapping: widget.pageSnapping,
//       onPageChanged: widget.onPageChanged,
//       itemBuilder: (context, index) {
//         final v = widget.itemBuilder(context, index);
//         if (v == null) {
//           return null;
//         } else if (v is Future) {
//           (v as Future).then((value) => )
//         }
//       },
//       findChildIndexCallback: widget.findChildIndexCallback,
//       itemCount: widget.itemCount,
//       dragStartBehavior: widget.dragStartBehavior,
//       allowImplicitScrolling: widget.allowImplicitScrolling,
//       restorationId: widget.restorationId,
//       clipBehavior: widget.clipBehavior,
//       scrollBehavior: widget.scrollBehavior,
//       padEnds: widget.padEnds,
//     );
//   }
// }
