import 'package:flutter/material.dart';

/// TODO: EVERYTHING
class WProgressiveImage extends StatefulWidget {
  const WProgressiveImage._({
    super.key,
    this.placeholder,
    this.thumbnail,
    this.image,
  });
  // const WProgressiveImage.({
  //   super.key,
  //   this.placeholder,
  //   this.thumbnail,
  //   this.image,
  // });
  final ImageProvider? placeholder;
  final ImageProvider? thumbnail;
  final ImageProvider? image;
  @override
  State<WProgressiveImage> createState() => _WProgressiveImageState();
}

class _WProgressiveImageState extends State<WProgressiveImage> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
class MyNetworkImage {
  final String uri;
  MyNetworkImage(this.uri);
}