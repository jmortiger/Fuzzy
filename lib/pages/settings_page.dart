import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/widgets/w_image_result.dart'
    show PostInfoPaneItem, imageFit;
import 'package:fuzzy/widget_lib.dart' as w;
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

// ignore: unnecessary_late
late final _logger = lm.generateLogger("SettingsPage").logger;

class SettingsPageRoute with IRoute<SettingsPage> {
  // #region Routing
  static const routeNameConst = "/settings",
      routeSegmentsConst = ["settings"],
      routePathConst = "/settings",
      hasStaticPathConst = false,
      $ = SettingsPageRoute();
  const SettingsPageRoute();

  @override
  get routeName => routeNameConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegmentsFolded => routePathConst;
  static bool acceptsRoutePath(RouteSettings settings) =>
      settings.name != null &&
      Uri.tryParse(settings.name!)?.path == routePathConst;

  @override
  bool acceptsRoute(RouteSettings settings) => acceptsRoutePath(settings);
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);

  static Widget generateWidgetForRouteStatic(RouteSettings settings) =>
      const SettingsPage();

  @override
  Widget? tryGenerateWidgetForRoute(RouteSettings settings) =>
      tryGenerateWidgetForRouteStatic(settings);

  static Widget? tryGenerateWidgetForRouteStatic(RouteSettings settings) {
    final Uri? uri;
    return settings.name == null ||
            (uri = Uri.tryParse(settings.name!)) == null ||
            uri!.path != routePathConst
        ? null
        : const SettingsPage();
  }
  // #endregion Routing
}

class SettingsPage extends StatelessWidget with IRoute<SettingsPage> {
  // #region Routing
  static const routeNameConst = "/settings",
      routeSegmentsConst = ["settings"],
      routePathConst = "/settings",
      hasStaticPathConst = false;

  @override
  get routeName => routeNameConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegmentsFolded => routePathConst;
  static bool acceptsRoutePath(RouteSettings settings) =>
      settings.name != null &&
      Uri.tryParse(settings.name!)?.path == routePathConst;

  @override
  bool acceptsRoute(RouteSettings settings) => acceptsRoutePath(settings);
  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);

  static Widget generateWidgetForRouteStatic(RouteSettings settings) =>
      const SettingsPage();

  @override
  Widget? tryGenerateWidgetForRoute(RouteSettings settings) =>
      tryGenerateWidgetForRouteStatic(settings);

  static Widget? tryGenerateWidgetForRouteStatic(RouteSettings settings) {
    final Uri? uri;
    return settings.name == null ||
            (uri = Uri.tryParse(settings.name!)) == null ||
            uri!.path != routePathConst
        ? null
        : const SettingsPage();
  }

  // #endregion Routing
  const SettingsPage({super.key});
  AppSettings get settings => AppSettings.i!;
  static final TextStyle titleStyle =
      const DefaultTextStyle.fallback().style.copyWith(
            fontSize: 24,
            color: Colors.white,
          );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        actions: [
          TextButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      content: const Text(
                        "All unsaved changes will be lost. Are you sure?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Accept"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                      ],
                    );
                  },
                ).then<void>(
                  (value) {
                    if (value ?? false) {
                      settings.overwriteWithRecord();
                    }
                  },
                );
              },
              child: const Text("Restore Default Settings")),
          TextButton(
            onPressed: () => settings
                .writeToFile()
                .then((val) => val ?? Future.sync(() => ""))
                .then((v) {
              _logger.fine(v);
              util.showUserMessage(
                // ignore: use_build_context_synchronously
                context: context,
                content: const Text("Saved!"),
                action: context.mounted
                    ? (
                        "See Contents",
                        () => context.mounted
                            ? showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SelectableText(
                                    "Saved: $v\nValue: ${jsonEncode(
                                      settings.toJson(),
                                    )}",
                                  ),
                                ),
                              )
                            : ""
                      )
                    : null,
              );
            }),
            child: const Text("Save Settings"),
          ),
          TextButton(
            onPressed: () => settings.loadFromFile().then((v) {
              util.showUserMessage(
                // ignore: use_build_context_synchronously
                context: context,
                content: const Text("Loaded from file!"),
                action: context.mounted
                    ? (
                        "See Contents",
                        () => context.mounted
                            ? showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SelectableText(
                                    "Loaded: ${jsonEncode(
                                      v.toJson(),
                                    )}\nValue: ${jsonEncode(
                                      settings.toJson(),
                                    )}",
                                  ),
                                ),
                              )
                            : ""
                      )
                    : null,
              );
            }),
            child: const Text("Load Settings"),
          ),
        ],
      ),
      body: const WFoldoutSettings(),
    );
  }
}

class WFoldoutSettings extends StatefulWidget {
  const WFoldoutSettings({super.key});

  @override
  State<WFoldoutSettings> createState() => _WFoldoutSettingsState();
}

class _WFoldoutSettingsState extends State<WFoldoutSettings> {
  TextStyle get titleStyle => SettingsPage.titleStyle;

  AppSettings get settings => AppSettings.i!;
  SearchView get sv => SearchView.i;
  PostView get pv => PostView.i;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ExpansionTile(
          title: Text("General Settings", style: SettingsPage.titleStyle),
          children: [
            w.WSetStringField(
              name: "Favorite Tags",
              subtitle: null,
              getVal: AppSettings.i!.favoriteTags,
              setVal: (Set<String> v) => AppSettings.i!.favoriteTags = v,
            ),
            w.WSetStringField(
              getVal: AppSettings.i!.blacklistedTags,
              subtitle: null,
              name: "Blacklisted Tags",
              setVal: (Set<String> v) => AppSettings.i!.blacklistedTags = v,
            ),
            w.WSetStringField.method(
              getValMethod: () => (SubscriptionManager.isInit
                      ? SubscriptionManager.subscriptions
                      : SubscriptionManager.storageSync ?? {})
                  .map((e) => e.tag)
                  .toSet(),
              name: "Subscribed Tags",
              setVal: (Set<String> v) {
                final toRemove = (SubscriptionManager.isInit
                        ? SubscriptionManager.subscriptions
                        : SubscriptionManager.loadFromStorageSync() ?? {})
                    .map((e) => e.tag)
                    .toSet()
                    .difference(v);
                for (var e in toRemove) {
                  SubscriptionManager.subscriptions
                      .removeWhere((element) => element.tag == e);
                }
                final toAdd = v.difference((SubscriptionManager.isInit
                        ? SubscriptionManager.subscriptions
                        : SubscriptionManager.loadFromStorageSync() ?? {})
                    .map((e) => e.tag)
                    .toSet());
                SubscriptionManager.subscriptions.addAll(toAdd.map(
                  (e) => TagSubscription(tag: e),
                ));
                SubscriptionManager.writeToStorage();
              },
            ),
            ListTile(
              title: const Text("Clear Cached Searches"),
              subtitle:
                  Text("Delete all ${CachedSearches.searches.length} searches"),
              onTap: CachedSearches.clear,
            ),
            w.WBooleanField.subtitleBuilder(
              getVal: () => AppSettings.i!.forceSafe,
              name: "Disable non-safe posts",
              subtitleBuilder: () => "Current site: ${e621.baseUri.toString()}",
              setVal: (bool val) => AppSettings.i!.forceSafe = val,
            ),
            w.WBooleanField(
              getVal: () => AppSettings.i!.autoLoadUserProfile,
              name: "Auto-load user profile",
              subtitle: "Load e621 user profile when required?",
              setVal: (bool val) => AppSettings.i!.autoLoadUserProfile = val,
            ),
            w.WBooleanField(
              getVal: () => AppSettings.i!.applyProfileBlacklist,
              name: "Apply Profile blacklist",
              subtitle:
                  "If profile is loaded, add its blacklist to the local blacklist",
              setVal: (bool val) => AppSettings.i!.applyProfileBlacklist = val,
            ),
            w.WBooleanField(
              getVal: () => AppSettings.i!.applyProfileFavTags,
              name: "Apply Profile Fav tags",
              subtitle:
                  "If profile is loaded, add its fav tags to the local fav tags",
              setVal: (bool val) => AppSettings.i!.applyProfileFavTags = val,
            ),
            w.WBooleanField(
              getVal: () => AppSettings.i!.upvoteOnFavorite,
              name: "Upvote on favorite",
              setVal: (bool val) => AppSettings.i!.upvoteOnFavorite = val,
            ),
            w.WBooleanField(
              getVal: () => AppSettings.i!.enableDownloads,
              name: "Enable downloads",
              setVal: (bool val) => AppSettings.i!.enableDownloads = val,
            ),
            w.WNumSliderField<int>(
              min: 0,
              max: 500,
              getVal: () => AppSettings.i!.maxSearchesToSave,
              name: "Searches to save",
              setVal: (num val) =>
                  AppSettings.i!.maxSearchesToSave = val.toInt(),
              validateVal: (num? val) => (val?.toInt() ?? -1) >= 0,
              defaultValue: AppSettingsRecord.defaultSettings.maxSearchesToSave,
              // divisions: 500,
              increment: 1,
              incrementMultiplier: 10,
            ),
          ],
        ),
        ExpansionTile(
          title: Text("Search View Settings", style: SettingsPage.titleStyle),
          children: [
            ListTile(
              title: TextField(
                onTap: () => FilePicker.platform.pickFiles(
                    allowedExtensions: ["gz", "csv"],
                    type: FileType.custom,
                    initialDirectory: sv.tagDbPath.isNotEmpty
                        ? sv.tagDbPath.substring(
                            0, sv.tagDbPath.lastIndexOf(RegExp(r"\\|/")))
                        : null).then(
                  (value) {
                    final v = (!Platform.isWeb
                            ? value?.paths.firstOrNull ??
                                value?.files.firstOrNull?.path
                            : null) ??
                        sv.tagDbPath;
                    if (v != sv.tagDbPath) {
                      setState(() {
                        sv.tagDbPath = v;
                      });
                    }
                  },
                ),
                readOnly: true,
                decoration: const InputDecoration(
                    labelText: "Tag database path",
                    hintText: "Tag database path"),
                controller: util.defaultSelection(sv.tagDbPath),
              ),
              subtitle: const Text("Used for search suggestions."),
            ),
            w.WNumSliderField<int>(
              min: SearchViewData.postsPerRowBounds.min,
              max: SearchViewData.postsPerRowBounds.max,
              getVal: () => sv.postsPerRow,
              name: "Posts per row",
              setVal: (num val) => sv.postsPerRow = val.toInt(),
              validateVal: (num? val) => (val?.toInt() ?? -1) >= 0,
              defaultValue: SearchViewData.defaultData.postsPerRow,
              divisions: SearchViewData.postsPerRowBounds.max -
                  SearchViewData.postsPerRowBounds.min,
              increment: 1,
            ),
            w.WNumSliderField<int>(
              min: SearchViewData.postsPerPageBounds.min,
              max: SearchViewData.postsPerPageBounds.max,
              getVal: () => sv.postsPerPage,
              name: "Posts per page",
              setVal: (num val) => sv.postsPerPage = val.round(),
              validateVal: (num? val) {
                final v = (val?.round() ?? -1);
                return v >= SearchViewData.postsPerPageBounds.min &&
                    v <= SearchViewData.postsPerPageBounds.max;
              },
              defaultValue: SearchViewData.defaultData.postsPerPage,
              divisions: SearchViewData.postsPerPageBounds.max -
                  SearchViewData.postsPerPageBounds.min,
              increment: 1,
            ),
            w.WNumSliderField<double>(
              min: SearchViewData.widthToHeightRatioBounds.min,
              max: SearchViewData.widthToHeightRatioBounds.max,
              getVal: () => sv.widthToHeightRatio,
              name: "Width to height ratio",
              setVal: (num val) => sv.widthToHeightRatio = val.toDouble(),
              validateVal: (num? val) {
                return (val ??
                            (SearchViewData.widthToHeightRatioBounds.min -
                                1)) >=
                        SearchViewData.widthToHeightRatioBounds.min &&
                    (val ?? -1) <= SearchViewData.widthToHeightRatioBounds.max;
              },
              defaultValue: SearchViewData.defaultData.widthToHeightRatio,
              // divisions: ((SearchViewData.widthToHeightRatioBounds.max -
              //     SearchViewData.widthToHeightRatioBounds.min)*100).round(),
              increment: .01,
            ),
            w.WNumSliderField<double>(
              getVal: () => sv.horizontalGridSpace,
              name: "Horizontal grid space",
              setVal: (num val) => sv.horizontalGridSpace = val.toDouble(),
              validateVal: (num? val) {
                return (val ??
                            (SearchViewData.horizontalGridSpaceBounds.min -
                                1)) >=
                        SearchViewData.horizontalGridSpaceBounds.min &&
                    (val ?? -1) <= SearchViewData.horizontalGridSpaceBounds.max;
              },
              min: SearchViewData.horizontalGridSpaceBounds.min,
              max: SearchViewData.horizontalGridSpaceBounds.max,
              defaultValue: SearchViewData.defaultData.horizontalGridSpace,
              // divisions: ((SearchViewData.horizontalGridSpaceBounds.max -
              //     SearchViewData.horizontalGridSpaceBounds.min)*100).round(),
              increment: .1,
              incrementMultiplier: 10,
            ),
            w.WNumSliderField<double>(
              getVal: () => sv.verticalGridSpace,
              name: "Vertical grid space",
              setVal: (num val) => sv.verticalGridSpace = val.toDouble(),
              validateVal: (num? val) {
                return (val ??
                            (SearchViewData.verticalGridSpaceBounds.min - 1)) >=
                        SearchViewData.verticalGridSpaceBounds.min &&
                    (val ?? -1) <= SearchViewData.verticalGridSpaceBounds.max;
              },
              min: SearchViewData.verticalGridSpaceBounds.min,
              max: SearchViewData.verticalGridSpaceBounds.max,
              defaultValue: SearchViewData.defaultData.verticalGridSpace,
              // divisions: ((SearchViewData.verticalGridSpaceBounds.max -
              //     SearchViewData.verticalGridSpaceBounds.min)*100).round(),
              increment: .1,
              incrementMultiplier: 10,
            ),
            w.WEnumSetField<PostInfoPaneItem>.getter(
              name: "Post Info Display",
              getter: () => sv.postInfoBannerItems,
              setVal: (v) =>
                  sv.postInfoBannerItems = v.cast<PostInfoPaneItem>(),
              values: PostInfoPaneItem.valuesSet,
            ),
            ListTile(
              title: const Text("Toggle Image Display Method"),
              onTap: () {
                _logger.finest("Before: ${imageFit.name}");
                setState(() {
                  imageFit = imageFit == BoxFit.contain
                      ? BoxFit.cover
                      : BoxFit.contain;
                });
                _logger.finer("After: ${imageFit.name}");
                // Navigator.pop(context);
              },
              trailing: Text(imageFit.name),
            ),
            w.WBooleanField(
              getVal: () => sv.useProgressiveImages,
              name: "Use Progressive Images",
              subtitle:
                  "Load a low-quality preview before loading the main image?",
              setVal: (bool val) => sv.useProgressiveImages = val,
            ),
            // WIntegerField(
            //   getVal: () => sv.numSavedSearchesInSearchBar,
            //   name: "# of prior searches in search bar",
            //   subtitle: "Limits the # of prior searches in the search "
            //       "bar's suggestions to prevent it from clogging results",
            //   setVal: (int val) =>
            //       sv.numSavedSearchesInSearchBar = val,
            //   validateVal: (int? val) => (val ?? -1) >= 0,
            // ),
            w.WNumSliderField<int>(
              min: 0,
              max: 20,
              getVal: () => sv.numSavedSearchesInSearchBar,
              name: "# of prior searches in search bar",
              subtitle: "Limits the # of prior searches in the search "
                  "bar's suggestions to prevent it from clogging results",
              setVal: (num val) => sv.numSavedSearchesInSearchBar = val.toInt(),
              validateVal: (num? val) => (val?.round() ?? -1) >= 0,
              defaultValue:
                  SearchViewData.defaultData.numSavedSearchesInSearchBar,
              divisions: 20,
              // useIncrementalButtons: true,
              increment: 1,
            ),
            w.WBooleanField(
              getVal: () => sv.lazyLoad,
              name: "Lazily load search results",
              // subtitle: "",
              setVal: (bool val) => sv.lazyLoad = val,
            ),
            w.WBooleanField(
              getVal: () => sv.lazyBuilding,
              name: "Lazily build tiles in grid view",
              // subtitle: "",
              setVal: (bool val) => sv.lazyBuilding = val,
            ),
            w.WBooleanField(
              getVal: () => sv.blacklistFavs,
              name: "Blacklist favorited posts",
              // subtitle: 'Apply blacklist to favorited posts.',
              setVal: (bool val) => sv.blacklistFavs = val,
            ),
            w.WBooleanField(
              getVal: () => sv.preferPoolName,
              name: "Prefer Pool name",
              subtitle:
                  'Wherever possible, search using a pool\'s name instead its id (e.g. "pool:my_pool" over "pool:123"). This will break saved searches if the name changes, and isn\'t available on pool names with invalid characters in them.',
              setVal: (bool val) => sv.preferPoolName = val,
            ),
            w.WBooleanField(
              getVal: () => sv.preferSetShortname,
              name: "Prefer set shortname",
              subtitle:
                  'Wherever possible, search using a set\'s shortname instead its id (e.g. "set:my_set" over "set:123"). This will break saved searches if the shortname changes.',
              setVal: (bool val) => sv.preferSetShortname = val,
            ),
          ],
        ),
        ExpansionTile(
          title: Text("Post View Settings", style: SettingsPage.titleStyle),
          children: [
            Text("Image Display", style: SettingsPage.titleStyle),
            w.WBooleanField(
              name: "Default to High Quality Image",
              subtitle:
                  "If the selected quality is unavailable, use the highest quality.",
              getVal: () => pv.forceHighQualityImage,
              setVal: (p1) => pv.forceHighQualityImage = p1,
            ),
            w.WEnumField(
              name: "Image Quality",
              getVal: () => pv.imageQuality,
              setVal: (/*FilterQuality*/ dynamic v) => pv.imageQuality = v,
              values: FilterQuality.values,
            ),
            w.WBooleanField(
              name: "Use Progressive Images",
              subtitle:
                  "Load a low-quality preview before loading the main image?",
              getVal: () => pv.useProgressiveImages,
              setVal: (p) => pv.useProgressiveImages = p,
            ),
            w.WEnumField<FilterQuality>(
              name: "Image Filter Quality",
              getVal: () => pv.imageFilterQuality,
              setVal: (/*FilterQuality*/ dynamic val) =>
                  pv.imageFilterQuality = val,
              values: FilterQuality.values,
            ),
            Text("Video Display", style: SettingsPage.titleStyle),
            w.WEnumField(
              name: "Video Quality",
              getVal: () => pv.videoQuality,
              setVal: (/*FilterQuality*/ dynamic v) => pv.videoQuality = v,
              values: FilterQuality.values,
            ),
            w.WBooleanField(
              name: "Autoplay Video",
              getVal: () => pv.autoplayVideo,
              setVal: (p1) => pv.autoplayVideo = p1,
            ),
            w.WBooleanField(
              name: "Start video muted",
              getVal: () => pv.startVideoMuted,
              setVal: (p1) => pv.startVideoMuted = p1,
            ),
            w.WBooleanField(
              name: "Show time left",
              subtitle: "When playing a video, show the time "
                  "remaining instead of the total duration?",
              getVal: () => pv.showTimeLeft,
              setVal: (p1) => pv.showTimeLeft = p1,
            ),
            /* WBooleanField(
              name: "Allow Overflow",
              getVal: () => pv.allowOverflow,
              setVal: (p1) => pv.allowOverflow = p1,
            ), */
            Text("Other", style: SettingsPage.titleStyle),
            w.WBooleanField(
              name: "Color Tag Headers",
              getVal: () => pv.colorTagHeaders,
              setVal: (p1) => pv.colorTagHeaders = p1,
            ),
            w.WBooleanField(
              name: "Color Tags",
              getVal: () => pv.colorTags,
              setVal: (p1) => pv.colorTags = p1,
            ),
            w.WBooleanField(
              name: "Start With Tags Expanded",
              getVal: () => pv.startWithTagsExpanded,
              setVal: (p) => pv.startWithTagsExpanded = p,
            ),
            w.WBooleanField(
              name: "Start With Description Expanded",
              getVal: () => pv.startWithDescriptionExpanded,
              setVal: (p) => pv.startWithDescriptionExpanded = p,
            ),
          ],
        ),
      ],
    );
  }
}
