import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart'
    show AssetImage, BoxFit, ResizeImage, VoidCallback, applyBoxFit;
import 'package:fuzzy/log_management.dart' as lm;

const placeholderPath = "assets/snake_loader.webp";
const placeholder = AssetImage(placeholderPath);
// final deletedPreviewImage = LazyInitializer<Image>(() => rootBundle.load("assets/deleted-preview.png").then((v) => Image.asset(name)))
const deletedPreviewImagePath = "assets/deleted-preview.png";

class StaticImageDataDeletedPreview {
  static const path = "assets/deleted-preview.png", width = 150, height = 150;
}

class StaticImageDataDeleted4x {
  static const path = "assets/deleted_4x.png", width = 600, height = 600;
}

class StaticImageDataNotFoundPreview {
  static const path = "assets/not_found.png", width = 150, height = 150;
}

class StaticImageDataNotFound4x {
  static const path = "assets/not_found_4x.png", width = 600, height = 600;
}

class ImgError {
  static const path = "assets/error.png", width = 200, height = 200;
}

typedef ImageRenderInfo = ({
  double aspectRatio,
  num? cacheHeight,
  num? cacheWidth,
  num height,
  num width
});

/// Determines the appropriate rendered dimensions, cached true resolution
/// dimensions (as per [ResizeImage]), and aspect ratio for displaying the
/// given image in the given area with the given fitment.
///
/// [fileWidth] & [fileHeight] are the image's natural, true,
/// full-size dimensions.
///
/// [sizeWidth] & [sizeHeight] are dimensions that the image is to be
/// rendered into. It is expected (but not required) that these do not match
/// the natural aspect ratio of the image; this method's job is to handle that.
///
/// [fit] is the logic by which the image is rendered to the display dimensions.
///
/// TODO: Test with non-finite [sizeWidth] &/or [sizeHeight].
///
/// TODO: Look into [applyBoxFit].
///
/// [applyBoxFit] doesn't seem to return the appropriate cache sizes
/// (which makes some sense as it seems to be lower level, past the point
/// of [ResizeImage]). As such, this is likely more memory-efficient.
///
/// Implementation Notes: Using the smaller of size(Dimension) and
/// file(Dimension) for the cache(Dimension) causes big scale-ups (e.g.
/// a long vertical comic) to have the wrong resolution, so cache is assigned
/// by rendered size (if finite & corresponds to [fit]) or the file resolution.
({
  num width,
  num height,
  num? cacheWidth,
  num? cacheHeight,
  double aspectRatio,
}) determineResolution(
  final int fileWidth,
  final int fileHeight,
  final num sizeWidth,
  final num sizeHeight,
  final BoxFit fit,
) {
  num width, height;
  num? cacheWidth, cacheHeight;
  final double widthRatio = fileWidth / sizeWidth;
  final double heightRatio = fileHeight / sizeHeight;
  final bool finiteRatios = widthRatio.isFinite && heightRatio.isFinite;
  if ((finiteRatios && widthRatio != heightRatio) || fileWidth != fileHeight) {
    switch (fit) {
      case BoxFit.scaleDown:
        if ((widthRatio <= 1 || !widthRatio.isFinite) &&
            (heightRatio <= 1 || !heightRatio.isFinite)) {
          continue none;
        } else {
          continue contain;
        }
      case BoxFit.fill:
        cacheWidth = fileWidth;
        cacheHeight = fileHeight;
        if (finiteRatios) {
          width = sizeWidth;
          height = sizeHeight;
        } else if (sizeWidth.isFinite || !sizeHeight.isFinite) {
          width = (sizeWidth.isFinite) ? sizeWidth : fileWidth;
          height = (fileHeight * width) / fileWidth;
        } else {
          height = (sizeHeight.isFinite) ? sizeHeight : fileHeight;
          width = (fileWidth * height) / fileHeight;
        }
        break;
      none:
      case BoxFit.none:
        cacheWidth = width = fileWidth;
        cacheHeight = height = fileHeight;
        break;
      fitHeight:
      case BoxFit.fitHeight:
        cacheHeight = (sizeHeight.isFinite) ? sizeHeight : null;
        height = cacheHeight ?? fileHeight;
        width = (fileWidth * height) / fileHeight;
        break;
      fitWidth:
      case BoxFit.fitWidth:
        cacheWidth = (sizeWidth.isFinite) ? sizeWidth : null;
        width = cacheWidth ?? fileWidth;
        height = (fileHeight * width) / fileWidth;
        break;
      case BoxFit.cover:
        if ((finiteRatios && heightRatio > widthRatio) ||
            (!finiteRatios && fileWidth < fileHeight)) {
          // (!finiteRatios && fileWidth > fileHeight)) {
          continue fitWidth;
        } else {
          continue fitHeight;
        }
      contain:
      case BoxFit.contain:
      default:
        if ((finiteRatios && heightRatio > widthRatio) ||
            (!finiteRatios && fileWidth < fileHeight)) {
          // (!finiteRatios && fileWidth > fileHeight)) {
          continue fitHeight;
        } else {
          continue fitWidth;
        }
    }
  } else {
    // TODO: This needs a switch too.
    cacheHeight = cacheWidth = (sizeHeight.isFinite)
        ? sizeHeight
        : (sizeWidth.isFinite)
            ? sizeWidth
            : null;
    height = width = (sizeHeight.isFinite)
        ? sizeHeight
        : (sizeWidth.isFinite)
            ? sizeWidth
            : fileWidth;
  }
  return (
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    aspectRatio: width / height,
  );
}

Future<String?> tryLoadSingleTextFile({
  String? dialogTitle,
  String? initialDirectory,
  FileType type = FileType.any,
  List<String>? allowedExtensions,
  dynamic Function(FilePickerStatus)? onFileLoading,
  bool allowCompression = true,
  int compressionQuality = 30,
  // bool allowMultiple = false,
  bool withData = false,
  bool withReadStream = false,
  bool lockParentWindow = false,
  bool readSequential = false,
  lm.FileLogger? logger,
  VoidCallback? afterSelectionCallback,
}) =>
    FilePicker.platform
        .pickFiles(
      dialogTitle: dialogTitle,
      allowedExtensions: allowedExtensions,
      type: allowedExtensions != null ? FileType.custom : type,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
      // allowMultiple: allowMultiple,
      initialDirectory: initialDirectory,
      onFileLoading: onFileLoading,
      lockParentWindow: lockParentWindow,
      withData: withData,
      readSequential: readSequential,
      withReadStream: withReadStream,
    )
        .then((result) {
      afterSelectionCallback?.call();
      Future<String?> f;
      if (result == null) {
        // User canceled the picker
        return null;
      } else {
        if (result.files.single.readStream != null) {
          f = utf8.decodeStream(result.files.single.readStream!);
        } else if (result.files.single.bytes != null) {
          f = Future.sync(
              () => utf8.decode(result.files.single.bytes!.toList()));
        } else {
          try {
            f = (File(result.files.single.path!).readAsString()
                    as Future<String?>)
                .onError((e, s) {
              logger?.severe("Failed import", e, s);
              return null;
            });
          } catch (e, s) {
            logger?.severe("Failed import", e, s);
            return null;
          }
        }
      }
      return f.onError((e, s) {
        logger?.severe("Failed import", e, s);
        return null;
      });
    });
