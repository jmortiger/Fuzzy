import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';

bool hasBlacklistedTag(Iterable<String> tagList) => tagList.reduceUntilTrue(
    (acc, e, _, __) => AppSettings.i!.blacklistedTagsAll.contains(e)
        ? (true, true)
        : (false, false),
    false);
/// Accounts for blacklisted tag
bool isBlacklisted(E6PostResponse post) =>
    (SearchView.i.blacklistFavs || !post.isFavorited) &&
    hasBlacklistedTag(post.tagList);
bool isDeleted(E6PostResponse post) => post.flags.deleted;
