import 'package:flutter/material.dart';
import 'package:fuzzy/util/asset_management.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:j_util/e621_api.dart' as e621;

class WPostThumbnail extends StatefulWidget {
  final double maxWidth;
  final double maxHeight;
  final bool maxDimensionIsWidth;
  final BoxFit fit;
  final int? id;
  final E6PostResponse? post;
  const WPostThumbnail.withId({
    super.key,
    required int this.id,
    this.maxWidth = 150,
    this.maxHeight = 150,
    this.fit = BoxFit.contain,
  })  : post = null,
        maxDimensionIsWidth = maxWidth >= maxHeight;
  const WPostThumbnail.withPost({
    super.key,
    required E6PostResponse this.post,
    this.maxWidth = 150,
    this.maxHeight = 150,
    this.fit = BoxFit.contain,
  })  : id = null,
        maxDimensionIsWidth = maxWidth >= maxHeight;

  @override
  State<WPostThumbnail> createState() => _WPostThumbnailState();
}

class _WPostThumbnailState extends State<WPostThumbnail> {
  ImageRenderInfo? renderData;
  IImageInfo? info;
  Future<IImageInfo?>? future;

  static IImageInfo retrieveImageInfo(E6PostResponse post) {
    return post.preview.hasValidUrl
        ? post.preview
        : post.sample.has
            ? post.sample
            : post.file;
  }

  // #region Init/Finalizer
  @override
  void initState() {
    super.initState();
    if (widget.post != null) {
      info = retrieveImageInfo(widget.post!);
    } else {
      future =
          e621.sendRequest(e621.initSearchPostRequest(widget.id!)).then((v) {
        return v.statusCode >= 300
            ? null
            : retrieveImageInfo(E6PostResponse.fromRawJson(v.body));
      })
            ..then((p) {
              setState(() {
                info = p ?? const ImageInfoRecord(ImgError.path, 200, 200);
                renderData = determineResolution(
                  info!.width,
                  info!.height,
                  widget.maxWidth,
                  widget.maxHeight,
                  widget.fit,
                );
                future?.ignore();
                future = null;
              });
            }).ignore();
    }
  }

  @override
  void dispose() {
    future?.ignore();
    future = null;
    super.dispose();
  }
  // #endregion Init/Finalizer

  @override
  Widget build(BuildContext context) {
    return future != null
        ? SizedBox(
            width: widget.maxWidth,
            height: widget.maxHeight,
            child: const AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            ),
          )
        : GestureDetector(
          onTap: () => Navigator.pushNamed(context, "/posts/${widget.id ?? widget.post?.id}", arguments: (id: widget.id ?? widget.post?.id, post: widget.post)),
          child: (info!.isWebResource ? Image.network : Image.asset)(
              info!.url,
              width: renderData!.width.toDouble(),
              height: renderData!.height.toDouble(),
              cacheHeight: renderData!.cacheHeight?.toInt(),
              cacheWidth: renderData!.cacheWidth?.toInt(),
            ),
        );
  }
}
class WPostThumbnailKey extends ValueKey {
  const WPostThumbnailKey({required int id,
    int maxWidth = 150,
    int maxHeight = 150,
    BoxFit fit = BoxFit.contain,}) : super("$id $maxWidth $maxHeight $fit");
  
}