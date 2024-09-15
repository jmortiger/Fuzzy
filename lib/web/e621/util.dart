import 'package:fuzzy/models/app_settings.dart';
import 'package:j_util/j_util_full.dart';

bool hasBlacklistedTag(Iterable<String> tagList) => tagList.reduceUntilTrue(
    (acc, e, _, __) => AppSettings.i!.blacklistedTagsAll.contains(e)
        ? (true, true)
        : (false, false),
    false);
