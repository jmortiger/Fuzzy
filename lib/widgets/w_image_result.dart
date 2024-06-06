import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fuzzy/web/site.dart';

import '../web/models/image_listing.dart';

// TODO: Fade in images https://docs.flutter.dev/cookbook/images/fading-in-images
class WImageResult extends StatefulWidget {
  // final Future<ImageListing> imageListing;
  final ImageListing imageListing;
  const WImageResult({
    super.key,
    required this.imageListing,
  });

  @override
  State<WImageResult> createState() => _WImageResultState();
}

class _WImageResultState extends State<WImageResult> {
  @override
  Widget build(BuildContext context) {
    return Image.network(widget.imageListing.imageUrl);
    // return FutureBuilder<ImageListing>(
    //   future: widget.imageListing,
    //   builder: (context, snapshot) {
    //     if (snapshot.hasData) {
    //       return Image.network(snapshot.data!.imageUrl);
    //     } else if (snapshot.hasError) {
    //       return Text('${snapshot.error}');
    //     }

    //     // By default, show a loading spinner.
    //     return const CircularProgressIndicator();
    //   },
    // );
  }
}
