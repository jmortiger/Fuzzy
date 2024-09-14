import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

// #region Logger
lm.Printer get _print => _lRecord.print;
lm.FileLogger get _logger => _lRecord.logger;
// ignore: unnecessary_late
late final _lRecord = lm.generateLogger("SettingsPage");
// #endregion Logger

class SettingsPage extends StatelessWidget implements IRoute<SettingsPage> {
  static const routeNameString = "/settings";
  @override
  get routeName => routeNameString;
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
                .then((val) => val?.readAsString() ?? Future.sync(() => ""))
                .then((v) {
              _print(v);
              util.showUserMessage(
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ExpansionTile(
          title: Text(
            "General Settings",
            style: SettingsPage.titleStyle,
          ),
          children: [
            WSetStringField(
              name: "Favorite Tags",
              subtitle: null,
              getVal: AppSettings.i!.favoriteTags,
              setVal: (Set<String> v) => AppSettings.i!.favoriteTags = v,
            ),
            WSetStringField(
              getVal: AppSettings.i!.blacklistedTags,
              subtitle: null,
              name: "Blacklisted Tags",
              setVal: (Set<String> v) => AppSettings.i!.blacklistedTags = v,
            ),
            WSetStringField.method(
              getValMethod: () => (SubscriptionManager.isInit
                      ? SubscriptionManager.subscriptions
                      : SubscriptionManager.storageSync ?? [])
                  .map((e) => e.tag)
                  .toSet(),
              subtitle: null,
              name: "Subscribed Tags",
              setVal: (Set<String> v) {
                final toRemove = (SubscriptionManager.isInit
                        ? SubscriptionManager.subscriptions
                        : SubscriptionManager.loadFromStorageSync() ?? [])
                    .map((e) => e.tag)
                    .toSet()
                    .difference(v);
                for (var e in toRemove) {
                  SubscriptionManager.subscriptions
                      .removeWhere((element) => element.tag == e);
                }
                final toAdd = v.difference((SubscriptionManager.isInit
                        ? SubscriptionManager.subscriptions
                        : SubscriptionManager.loadFromStorageSync() ?? [])
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
            WBooleanField.subtitleBuilder(
              getVal: () => AppSettings.i!.forceSafe,
              name: "Disable non-safe posts",
              subtitleBuilder: () => "Current site: ${e621.baseUri.toString()}",
              setVal: (bool val) => AppSettings.i!.forceSafe = val,
            ),
            WBooleanField(
              getVal: () => AppSettings.i!.autoLoadUserProfile,
              name: "Auto-load user profile",
              subtitle: "Load e621 user profile when required?",
              setVal: (bool val) => AppSettings.i!.autoLoadUserProfile = val,
            ),
            WBooleanField(
              getVal: () => AppSettings.i!.applyProfileBlacklist,
              name: "Apply Profile blacklist",
              subtitle:
                  "If profile is loaded, add its blacklist to the local blacklist",
              setVal: (bool val) => AppSettings.i!.applyProfileBlacklist = val,
            ),
            WBooleanField(
              getVal: () => AppSettings.i!.applyProfileFavTags,
              name: "Apply Profile Fav tags",
              subtitle:
                  "If profile is loaded, add its fav tags to the local fav tags",
              setVal: (bool val) => AppSettings.i!.applyProfileFavTags = val,
            ),
            WBooleanField(
              getVal: () => AppSettings.i!.upvoteOnFavorite,
              name: "Upvote on favorite",
              setVal: (bool val) => AppSettings.i!.upvoteOnFavorite = val,
            ),
            // if (!AppSettings.i!.autoLoadUserProfile)
            //   WBooleanField(
            //     getVal: () => AppSettings.i!.autoLoadUserProfile,
            //     name: "Load user profile ",
            //     subtitle: "Current site: ${e621.baseUri.toString()}",
            //     setVal: (bool val) => SearchView.i.lazyBuilding = val,
            //   ),
            WNumSliderField<int>(
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
              WNumSliderField<int>(
                min: SearchViewData.postsPerRowBounds.min,
                max: SearchViewData.postsPerRowBounds.max,
                getVal: () => SearchView.i.postsPerRow,
                name: "Posts per row",
                setVal: (num val) => SearchView.i.postsPerRow = val.toInt(),
                validateVal: (num? val) => (val?.toInt() ?? -1) >= 0,
                defaultValue: SearchViewData.defaultData.postsPerRow,
                divisions: SearchViewData.postsPerRowBounds.max -
                    SearchViewData.postsPerRowBounds.min,
                increment: 1,
              ),
              WNumSliderField<int>(
                min: SearchViewData.postsPerPageBounds.min,
                max: SearchViewData.postsPerPageBounds.max,
                getVal: () => SearchView.i.postsPerPage,
                name: "Posts per page",
                setVal: (num val) => SearchView.i.postsPerPage = val.round(),
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
              WNumSliderField<double>(
                min: SearchViewData.widthToHeightRatioBounds.min,
                max: SearchViewData.widthToHeightRatioBounds.max,
                getVal: () => SearchView.i.widthToHeightRatio,
                name: "Width to height ratio",
                setVal: (num val) =>
                    SearchView.i.widthToHeightRatio = val.toDouble(),
                validateVal: (num? val) {
                  return (val ??
                              (SearchViewData.widthToHeightRatioBounds.min -
                                  1)) >=
                          SearchViewData.widthToHeightRatioBounds.min &&
                      (val ?? -1) <=
                          SearchViewData.widthToHeightRatioBounds.max;
                },
                defaultValue: SearchViewData.defaultData.widthToHeightRatio,
                // divisions: ((SearchViewData.widthToHeightRatioBounds.max -
                //     SearchViewData.widthToHeightRatioBounds.min)*100).round(),
                increment: .01,
              ),
              WNumSliderField<double>(
                getVal: () => SearchView.i.horizontalGridSpace,
                name: "Horizontal grid space",
                setVal: (num val) =>
                    SearchView.i.horizontalGridSpace = val.toDouble(),
                validateVal: (num? val) {
                  return (val ??
                              (SearchViewData.horizontalGridSpaceBounds.min -
                                  1)) >=
                          SearchViewData.horizontalGridSpaceBounds.min &&
                      (val ?? -1) <=
                          SearchViewData.horizontalGridSpaceBounds.max;
                },
                min: SearchViewData.horizontalGridSpaceBounds.min,
                max: SearchViewData.horizontalGridSpaceBounds.max,
                defaultValue: SearchViewData.defaultData.horizontalGridSpace,
                // divisions: ((SearchViewData.horizontalGridSpaceBounds.max -
                //     SearchViewData.horizontalGridSpaceBounds.min)*100).round(),
                increment: .1,
                incrementMultiplier: 10,
              ),
              WNumSliderField<double>(
                getVal: () => SearchView.i.verticalGridSpace,
                name: "Vertical grid space",
                setVal: (num val) =>
                    SearchView.i.verticalGridSpace = val.toDouble(),
                validateVal: (num? val) {
                  return (val ??
                              (SearchViewData.verticalGridSpaceBounds.min -
                                  1)) >=
                          SearchViewData.verticalGridSpaceBounds.min &&
                      (val ?? -1) <=
                          SearchViewData.verticalGridSpaceBounds.max;
                },
                min: SearchViewData.verticalGridSpaceBounds.min,
                max: SearchViewData.verticalGridSpaceBounds.max,
                defaultValue: SearchViewData.defaultData.verticalGridSpace,
                // divisions: ((SearchViewData.verticalGridSpaceBounds.max -
                //     SearchViewData.verticalGridSpaceBounds.min)*100).round(),
                increment: .1,
                incrementMultiplier: 10,
              ),
              WEnumListField<PostInfoPaneItem>.getter(
                name: "Post Info Display",
                getter: () => SearchView.i.postInfoBannerItems,
                setVal: (/* List<PostInfoPaneItem>  */ val) => SearchView
                    .i.postInfoBannerItems = val.cast<PostInfoPaneItem>(),
                values: PostInfoPaneItem.values,
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
              WBooleanField(
                getVal: () => SearchView.i.useProgressiveImages,
                name: "Use Progressive Images",
                subtitle:
                    "Load a low-quality preview before loading the main image?",
                setVal: (bool val) => SearchView.i.useProgressiveImages = val,
              ),
              // WIntegerField(
              //   getVal: () => SearchView.i.numSavedSearchesInSearchBar,
              //   name: "# of prior searches in search bar",
              //   subtitle: "Limits the # of prior searches in the search "
              //       "bar's suggestions to prevent it from clogging results",
              //   setVal: (int val) =>
              //       SearchView.i.numSavedSearchesInSearchBar = val,
              //   validateVal: (int? val) => (val ?? -1) >= 0,
              // ),
              WNumSliderField<int>(
                min: 0,
                max: 20,
                getVal: () => SearchView.i.numSavedSearchesInSearchBar,
                name: "# of prior searches in search bar",
                subtitle: "Limits the # of prior searches in the search "
                    "bar's suggestions to prevent it from clogging results",
                setVal: (num val) =>
                    SearchView.i.numSavedSearchesInSearchBar = val.toInt(),
                validateVal: (num? val) => (val?.round() ?? -1) >= 0,
                defaultValue:
                    SearchViewData.defaultData.numSavedSearchesInSearchBar,
                divisions: 20,
                // useIncrementalButtons: true,
                increment: 1,
              ),
              WBooleanField(
                getVal: () => SearchView.i.lazyLoad,
                name: "Lazily load search results",
                // subtitle: "",
                setVal: (bool val) => SearchView.i.lazyLoad = val,
              ),
              WBooleanField(
                getVal: () => SearchView.i.lazyBuilding,
                name: "Lazily build tiles in grid view",
                // subtitle: "",
                setVal: (bool val) => SearchView.i.lazyBuilding = val,
              ),
              WBooleanField(
                getVal: () => SearchView.i.preferSetShortname,
                name: "Prefer set shortname",
                subtitle:
                    'Wherever possible, search using a set\'s shortname instead its id (e.g. "set:my_set" over "set:123"). This will break saved searches if the shortname changes.',
                setVal: (bool val) => SearchView.i.preferSetShortname = val,
              ),
            ]),
        ExpansionTile(
          title: Text(
            "Post View Settings",
            style: SettingsPage.titleStyle,
          ),
          children: [
            Text(
              "Image Display",
              style: SettingsPage.titleStyle,
            ),
            WBooleanField(
              name: "Default to High Quality Image",
              subtitle:
                  "If the selected quality is unavailable, use the highest quality.",
              getVal: () => PostView.i.forceHighQualityImage,
              setVal: (p1) => PostView.i.forceHighQualityImage = p1,
            ),
            WEnumField(
              name: "Image Quality",
              getVal: () => PostView.i.imageQuality,
              setVal: (/*FilterQuality*/ dynamic v) =>
                  PostView.i.imageQuality = v,
              values: FilterQuality.values,
            ),
            WBooleanField(
              name: "Use Progressive Images",
              subtitle:
                  "Load a low-quality preview before loading the main image?",
              getVal: () => PostView.i.useProgressiveImages,
              setVal: (p) => PostView.i.useProgressiveImages = p,
            ),
            WEnumField<FilterQuality>(
              name: "Image Filter Quality",
              getVal: () => PostView.i.imageFilterQuality,
              setVal: (/*FilterQuality*/ dynamic val) =>
                  PostView.i.imageFilterQuality = val,
              values: FilterQuality.values,
            ),
            Text(
              "Video Display",
              style: SettingsPage.titleStyle,
            ),
            WEnumField(
              name: "Video Quality",
              getVal: () => PostView.i.videoQuality,
              setVal: (/*FilterQuality*/ dynamic v) =>
                  PostView.i.videoQuality = v,
              values: FilterQuality.values,
            ),
            WBooleanField(
              name: "Autoplay Video",
              getVal: () => PostView.i.autoplayVideo,
              setVal: (p1) => PostView.i.autoplayVideo = p1,
            ),
            WBooleanField(
              name: "Start video muted",
              getVal: () => PostView.i.startVideoMuted,
              setVal: (p1) => PostView.i.startVideoMuted = p1,
            ),
            WBooleanField(
              name: "Show time left",
              subtitle: "When playing a video, show the time "
                  "remaining instead of the total duration?",
              getVal: () => PostView.i.showTimeLeft,
              setVal: (p1) => PostView.i.showTimeLeft = p1,
            ),
            /* WBooleanField(
              name: "Allow Overflow",
              getVal: () => PostView.i.allowOverflow,
              setVal: (p1) => PostView.i.allowOverflow = p1,
            ), */
            Text(
              "Other",
              style: SettingsPage.titleStyle,
            ),
            WBooleanField(
              name: "Color Tag Headers",
              getVal: () => PostView.i.colorTagHeaders,
              setVal: (p1) => PostView.i.colorTagHeaders = p1,
            ),
            WBooleanField(
              name: "Color Tags",
              getVal: () => PostView.i.colorTags,
              setVal: (p1) => PostView.i.colorTags = p1,
            ),
            WBooleanField(
              name: "Start With Tags Expanded",
              getVal: () => PostView.i.startWithTagsExpanded,
              setVal: (p) => PostView.i.startWithTagsExpanded = p,
            ),
            WBooleanField(
              name: "Start With Description Expanded",
              getVal: () => PostView.i.startWithDescriptionExpanded,
              setVal: (p) => PostView.i.startWithDescriptionExpanded = p,
            ),
          ],
        ),
      ],
    );
  }
}

// #region Fields
class WBooleanField extends StatefulWidget {
  final String name;
  final String? subtitle;
  final String Function()? subtitleBuilder;

  final bool Function() getVal;

  final void Function(bool p1) setVal;

  final bool Function(bool? p1)? validateVal;

  const WBooleanField({
    super.key,
    required this.name,
    this.subtitle,
    required this.getVal,
    required this.setVal,
    // required this.settings,
    this.validateVal,
  }) : subtitleBuilder = null;
  const WBooleanField.subtitleBuilder({
    super.key,
    required this.name,
    this.subtitleBuilder,
    required this.getVal,
    required this.setVal,
    // required this.settings,
    this.validateVal,
  }) : subtitle = null;

  // final AppSettings settings;

  @override
  State<WBooleanField> createState() => _WBooleanFieldState();
}

class _WBooleanFieldState extends State<WBooleanField> {
  void onChanged([bool? value]) =>
      widget.validateVal?.call(value ?? !widget.getVal()) ?? true
          ? setState(() {
              widget.setVal(value ?? !widget.getVal());
            })
          : null;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.name),
      subtitle: (widget.subtitle ?? widget.subtitleBuilder) != null
          ? Text(widget.subtitle ?? widget.subtitleBuilder!())
          : null,
      onTap: onChanged,
      trailing: Checkbox(
        onChanged: onChanged,
        value: widget.getVal(),
      ),
    );
  }
}

class WBooleanTristateField extends StatefulWidget {
  final String name;
  final String? subtitle;

  final bool? Function() getVal;

  final void Function(bool? p1) setVal;

  final bool Function(bool? p1)? validateVal;

  const WBooleanTristateField({
    super.key,
    required this.name,
    this.subtitle,
    required this.getVal,
    required this.setVal,
    // required this.settings,
    this.validateVal,
  });

  // final AppSettings settings;

  @override
  State<WBooleanTristateField> createState() => _WBooleanTristateFieldState();
}

class _WBooleanTristateFieldState extends State<WBooleanTristateField> {
  void onChanged([bool? value]) => widget.validateVal?.call(value) ?? true
      ? setState(() {
          widget.setVal(value);
        })
      : null;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.name),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      onTap: onChanged,
      trailing: Checkbox(
        tristate: true,
        onChanged: onChanged,
        value: widget.getVal(),
      ),
    );
  }
}

class WSetStringField extends StatefulWidget {
  final String name;

  /// Null for generated subtitle, empty string for no subtitle
  /// Defaults to empty string
  final String? subtitle;

  Set<String> get val => getVal ?? getValMethod!();
  final Set<String>? getVal;
  final Set<String> Function()? getValMethod;

  final void Function(Set<String> p1) setVal;

  final bool Function(Set<String>? p1)? validateVal;
  const WSetStringField({
    super.key,
    required this.name,
    this.subtitle = "",
    required Set<String> this.getVal,
    required this.setVal,
    this.validateVal,
  }) : getValMethod = null;
  const WSetStringField.method({
    super.key,
    required this.name,
    this.subtitle = "",
    required Set<String> Function() this.getValMethod,
    required this.setVal,
    this.validateVal,
  }) : getVal = null;

  @override
  State<WSetStringField> createState() => _WSetStringFieldState();
}

class _WSetStringFieldState extends State<WSetStringField> {
  Set<String> get getVal => widget.val;

  void Function(Set<String> p1) get setVal => widget.setVal;

  bool Function(Set<String>? p1)? get validateVal => widget.validateVal;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(getVal),
      title: Text(widget.name),
      subtitle: widget.subtitle?.isNotEmpty ?? true
          ? Text(widget.subtitle ?? getVal.toString())
          : null,
      onTap: () {
        final before = getVal.fold(
          "",
          (previousValue, element) => "$previousValue$element\n",
        );
        var t = before;
        validation(String value) {
          validateVal?.call(
                    value.split(RegExp(r"\s")).toSet(),
                  ) ??
                  true
              ? t = value
              : null;
        }

        showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: TextField(
                maxLines: null,
                onChanged: validation,
                onSubmitted: validation,
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: t,
                    selection: TextSelection(
                      baseOffset: 0,
                      extentOffset: t.length - 1,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, t),
                  child: const Text("Accept"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        ).then<void>(
          (value) {
            if (value != null) {
              _print("Before: ${getVal.toString()}");
              if (getVal.isNotEmpty) {
                getVal.clear();
              }
              setState(() {
                setVal(getVal
                  ..addAll(
                      value.split(RegExp(r"\s")).where((s) => s.isNotEmpty)));
              });
              _print("After: ${getVal.toString()}");
            }
          },
        ).onError((error, stackTrace) => _print(error));
      },
    );
  }
}

class WEnumListField<T extends Enum> extends StatefulWidget {
  final String name;

  /// Either this or [getter] are required.
  final List<T>? getVal;

  /// Either this or [getVal] are required.
  final List<T> Function()? getter;

  final void Function(List /* <T> */ p1) setVal;

  final bool Function(List<T>? p1)? validateVal;

  /// Needed because I can't access [T.values] from here.
  final List<T> values;

  final String Function(T v)? enumToString;

  final T Function(String v)? stringToEnum;
  // const WEnumListField({
  //   super.key,
  //   required this.name,
  //   this.getVal,
  //   this.getter,
  //   required this.setVal,
  //   this.validateVal,
  //   required this.values,
  //   this.enumToString,
  //   this.stringToEnum,
  // });
  const WEnumListField.getter({
    super.key,
    required this.name,
    required this.getter,
    required this.setVal,
    this.validateVal,
    required this.values,
    this.enumToString,
    this.stringToEnum,
  }) : getVal = null;
  const WEnumListField.value({
    super.key,
    required this.name,
    required this.getVal,
    required this.setVal,
    this.validateVal,
    required this.values,
    this.enumToString,
    this.stringToEnum,
  }) : getter = null;

  @override
  State<WEnumListField> createState() => _WEnumListFieldState();
}

class _WEnumListFieldState<T extends Enum> extends State<WEnumListField<T>> {
  String get name => widget.name;

  List<T> get getVal =>
      widget.getVal ??
      widget.getter?.call() ??
      (throw StateError(
        "Either widget.getVal or widget.getter must be a non-null value",
      ));

  Function get setVal => widget.setVal;

  bool Function(List<T>? p1)? get validateVal => widget.validateVal;

  List<T> convertInputToValue(String input) {
    return input.split(RegExp(r"\s")).where((s) => s.isNotEmpty).mapAsList(
          (e, index, list) => convertInputToEnumValue(e),
        );
  }

  String convertValueToInput(List<T> value) {
    return value.fold(
      "",
      (acc, e) => "$acc${convertEnumValueToInput(e)}\n",
    );
  }

  String convertEnumValueToInput(T value) =>
      widget.enumToString?.call(value) ?? value.name;
  T convertInputToEnumValue(String value) =>
      widget.stringToEnum?.call(value) ??
      widget.values.singleWhere((v) => v.name == value);
  late List<T> temp;
  @override
  void initState() {
    super.initState();
    temp = List.of(getVal);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(getVal),
      title: Text(name),
      subtitle: Text(getVal.toString()),
      onTap: () {
        // final before = convertValueToInput(getVal);
        // var t = before;
        // showDialog<String>(
        showDialog<List<T>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              // content: _buildTextEntry(t),
              content: SizedBox(
                width: double.maxFinite,
                height: double.maxFinite,
                child: WEnumListFieldContent(
                  enumToString: widget.enumToString,
                  values: widget.values,
                  initialState: temp,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, temp),
                  child: const Text("Accept"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        ).then<void>(
          (value) {
            if (value != null) {
              _logger
                  .finer("_EnumListFieldState: Before: ${getVal.toString()}");
              setState(() {
                setVal(value);
              });
              _logger.fine("_EnumListFieldState: After: ${getVal.toString()}");
            }
          },
        ).onError(
            (error, stackTrace) => _logger.severe(error, error, stackTrace));
      },
    );
  }
}

/// Abuses reference to [initialState] to send data back.
class WEnumListFieldContent<T extends Enum> extends StatefulWidget {
  final List<T> initialState;

  /// Needed because I can't access [T.values] from here.
  final List<T> values;

  final String Function(T v)? enumToString;

  const WEnumListFieldContent({
    super.key,
    required this.initialState,
    required this.values,
    this.enumToString,
  });

  @override
  State<WEnumListFieldContent> createState() => _WEnumListFieldContentState();
}

class _WEnumListFieldContentState<T extends Enum>
    extends State<WEnumListFieldContent<T>> {
  /* late  */ List<T> get temp => widget.initialState;
  // @override
  // void initState() {
  //   super.initState();
  //   temp = widget.initialState;
  // }

  String convertEnumValueToInput(T value) =>
      widget.enumToString?.call(value) ?? value.name;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: temp.mapAsList(
        (e, i, list) => ListTile(
          // leading: Text(i.toString()),
          leading: IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => setState(() {
              temp.removeAt(i);
            }),
          ),
          title: DropdownMenu<T>(
            dropdownMenuEntries: widget.values
                .map((v) => DropdownMenuEntry(
                      value: v,
                      label: convertEnumValueToInput(v),
                    ))
                .toList(),
            initialSelection: e,
            onSelected: (value) {
              if (value != null) {
                setState(() {
                  temp[i] = value;
                });
              }
            },
          ),
        ),
      )..add(ListTile(
          title: const Text("Add"),
          onTap: () => setState(() {
            temp.add(widget.values.first);
          }),
        )),
    );
  }
}
// class WListEntryField<T> extends StatelessWidget {
//   final Function? onTrailingPressed;
//   const WListEntryField({super.key, this.onTrailingPressed, });
//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }
// }

class WIntegerField extends StatefulWidget {
  final String name;
  final String? subtitle;

  final int Function() getVal;

  final int Function(int p1) setVal;

  final bool Function(int? p1)? validateVal;
  const WIntegerField({
    super.key,
    required this.name,
    required this.getVal,
    required this.setVal,
    this.validateVal,
    this.subtitle,
  });

  @override
  State<WIntegerField> createState() => _WIntegerFieldState();
}

class _WIntegerFieldState extends State<WIntegerField> {
  String get name => widget.name;
  String? get subtitle => widget.subtitle;

  int get getVal => widget.getVal();

  int Function(int p1) get setVal => widget.setVal;

  bool Function(int? p1)? get validateVal => widget.validateVal;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(getVal),
      title: Text(name),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Text(getVal.toString()),
      leadingAndTrailingTextStyle:
          SettingsPage.titleStyle.copyWith(fontSize: 20),
      onTap: buildNumericalEntryDialog(
        context: context,
        getVal: getVal,
        parse: int.parse,
        tryParse: int.tryParse,
        validateVal: validateVal,
        onSetVal: (value) {
          _print("Before: $getVal");
          setState(() => setVal(value));
          _print("After: $getVal");
          _print(jsonEncode(AppSettings.i));
        },
      ),
      // onTap: () {
      //   var t = getVal.toString();
      //   validation(String value) {
      //     (validateVal?.call(int.tryParse(value)) ?? true) ? t = value : null;
      //   }

      //   showDialog<int>(
      //     context: context,
      //     builder: (context) {
      //       return AlertDialog(
      //         content: TextField(
      //           keyboardType: TextInputType.number,
      //           maxLines: null,
      //           autofocus: true,
      //           onChanged: validation,
      //           onSubmitted: (v) {
      //             validation(v);
      //             Navigator.pop(context, int.parse(t));
      //           },
      //           controller: TextEditingController.fromValue(
      //             TextEditingValue(
      //               text: t,
      //               selection: TextSelection(
      //                 baseOffset: 0,
      //                 extentOffset: t.length,
      //               ),
      //             ),
      //           ),
      //         ),
      //         actions: [
      //           TextButton(
      //             onPressed: () => Navigator.pop(context, int.parse(t)),
      //             child: const Text("Accept"),
      //           ),
      //           TextButton(
      //             onPressed: () => Navigator.pop(context, null),
      //             child: const Text("Cancel"),
      //           ),
      //         ],
      //       );
      //     },
      //   )
      //       .then<void>((value) {
      //         if (validateVal?.call(value) ?? value != null) {
      //           _print("Before: $getVal");
      //           setState(() => setVal(value!));
      //           _print("After: $getVal");
      //           _print(jsonEncode(AppSettings.i));
      //         }
      //       })
      //       .onError(
      //         (error, stackTrace) => _logger.severe(error, error, stackTrace),
      //       )
      //       .ignore();
      // },
    );
  }
}

class WNumSliderField<T extends num> extends StatefulWidget {
  final String name;

  final String? subtitle;

  final T Function() getVal;

  final T Function(num p1) setVal;

  final bool Function(num? p1)? validateVal;

  final T min;

  final T max;

  final T? defaultValue;

  final int? divisions;
  // final bool useIncrementalButtons;
  final T? increment;
  final T? incrementMultiplier;
  const WNumSliderField({
    super.key,
    required this.name,
    this.subtitle,
    required this.getVal,
    required this.setVal,
    required this.min,
    required this.max,
    this.divisions,
    this.defaultValue,
    this.validateVal,
    this.increment,
    this.incrementMultiplier,
  });

  @override
  State<WNumSliderField<T>> createState() => _WNumSliderFieldState<T>();
}

class _WNumSliderFieldState<T extends num> extends State<WNumSliderField<T>> {
  String get name => widget.name;

  T get getVal => widget.getVal();

  T Function(num p1) get setVal => widget.setVal;

  bool Function(num? p1)? get validateVal => widget.validateVal;
  // Build fails on android w/o unnecessary cast.
  num Function(String) get parse =>
      // ignore: unnecessary_cast
      (T is int ? int.parse : double.parse) as num Function(String);
  // T Function(String) get parse => switch (T) {
  //   int => int.parse as T Function(String),
  //   double => double.parse as T Function(String),
  //   Type() => throw UnimplementedError(),
  // };
  num? Function(String) get tryParse =>
      (T is int ? int.tryParse : double.tryParse);

  double tempValue = 0;

  int? get divisions =>
      widget.divisions ??
      ((T.runtimeType == int)
          ? (widget.max.toInt() - widget.min.toInt())
          : null);

  @override
  void initState() {
    super.initState();
    tempValue = getVal.toDouble();
  }

  String makeLabel(num n) {
    final s = n.toString();
    return s.substring(0, math.min(5, s.length));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leadingAndTrailingTextStyle:
          SettingsPage.titleStyle.copyWith(fontSize: 20),
      title: Row(
        children: [
          Text(name),
          if (widget.increment != null && (widget.incrementMultiplier ?? 0) > 1)
            IconButton(
              onPressed: validateVal?.call(getVal -
                          (widget.increment! * widget.incrementMultiplier!)) ??
                      true
                  ? () => setState(() {
                        tempValue = setVal(getVal -
                            (widget.increment! *
                                widget.incrementMultiplier!)) as double;
                      })
                  : null,
              icon: const Icon(Icons.keyboard_double_arrow_left),
            ),
          if (widget.increment != null)
            IconButton(
              onPressed: validateVal?.call(getVal - widget.increment!) ?? true
                  ? () => setState(() {
                        tempValue =
                            setVal(getVal - widget.increment!) as double;
                      })
                  : null,
              icon: const Icon(Icons.arrow_left),
            ),
          Expanded(
            child: Slider(
              label: makeLabel(getVal),
              value: tempValue, //getVal.toDouble(),
              onChanged: (v) => (validateVal?.call(v) ?? true)
                  ? setState(() => tempValue = setVal(v).toDouble())
                  : setState(() => tempValue = v),
              min: widget.min.toDouble(),
              max: widget.max.toDouble(),
              secondaryTrackValue: widget.defaultValue?.toDouble(),
              divisions: divisions,
            ),
          ),
          if (widget.increment != null)
            IconButton(
              onPressed: validateVal?.call(getVal + widget.increment!) ?? true
                  ? () => setState(() {
                        tempValue =
                            setVal(getVal + widget.increment!) as double;
                      })
                  : null,
              icon: const Icon(Icons.arrow_right),
            ),
          if (widget.increment != null && (widget.incrementMultiplier ?? 0) > 1)
            IconButton(
              onPressed: validateVal?.call(getVal +
                          widget.increment! * widget.incrementMultiplier!) ??
                      true
                  ? () => setState(() {
                        tempValue = setVal(getVal +
                                widget.increment! * widget.incrementMultiplier!)
                            as double;
                      })
                  : null,
              icon: const Icon(Icons.keyboard_double_arrow_right),
            ),
        ],
      ),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: TextButton(
        onPressed: buildNumericalEntryDialog(
          context: context,
          getVal: getVal,
          onSetVal: (num value) {
            _logger.finer("Before: $getVal");
            setState(() {
              tempValue = setVal(value).toDouble();
            });
            _logger.fine("After: $getVal");
            _logger.fine(jsonEncode(AppSettings.i));
          },
          parse: parse,
          tryParse: tryParse,
          validateVal: validateVal,
        ),
        child: Text(makeLabel(tempValue)),
      ),
    );
  }
}

VoidFunction buildNumericalEntryDialog<T extends num>({
  required BuildContext context,
  required T getVal,
  bool Function(T?)? validateVal,
  required T? Function(String) tryParse,
  required T Function(String) parse,
  required void Function(T) onSetVal,
}) =>
    () {
      var t = getVal.toString();
      void validation(String value) {
        (validateVal?.call(tryParse(value)) ?? true) ? t = value : null;
      }

      showDialog<T>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: TextField(
              keyboardType: TextInputType.number,
              maxLines: null,
              autofocus: true,
              onChanged: validation,
              onSubmitted: (v) {
                validation(v);
                Navigator.pop(context, parse(t));
              },
              controller: TextEditingController.fromValue(
                TextEditingValue(
                  text: t,
                  selection: TextSelection(
                    baseOffset: 0,
                    extentOffset: t.length,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, parse(t)),
                child: const Text("Accept"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("Cancel"),
              ),
            ],
          );
        },
      )
          .then<void>((value) {
            if (validateVal?.call(value) ?? value != null) {
              onSetVal(value!);
            }
          })
          .onError(
              (error, stackTrace) => _logger.severe(error, error, stackTrace))
          .ignore();
    };

class WIntegerSliderField extends StatefulWidget {
  final String name;

  final String? subtitle;

  final int Function() getVal;

  final void Function(int p1) setVal;

  final bool Function(int? p1)? validateVal;

  final int min;

  final int max;

  final int? defaultValue;

  const WIntegerSliderField({
    super.key,
    required this.name,
    this.subtitle,
    required this.getVal,
    required this.setVal,
    required this.min,
    required this.max,
    this.defaultValue,
    this.validateVal,
  });

  @override
  State<WIntegerSliderField> createState() => _WIntegerSliderFieldState();
}

class _WIntegerSliderFieldState extends State<WIntegerSliderField> {
  String get name => widget.name;

  int get getVal => widget.getVal();

  void Function(int p1) get setVal => widget.setVal;

  bool Function(int? p1)? get validateVal => widget.validateVal;

  double tempValue = 0;

  int? get divisions => (widget.max.toInt() - widget.min.toInt());

  @override
  void initState() {
    super.initState();
    tempValue = getVal.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(children: [
        Text(name),
        Slider(
          label: getVal.toString(),
          value: getVal.toDouble(),
          onChanged: (v) => (validateVal?.call(v.toInt()) ?? true)
              ? setState(() => setVal((tempValue = v).toInt()))
              : setState(() {
                  tempValue = v;
                }),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: divisions,
        )
      ]),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: Text(getVal.toString()),
      leadingAndTrailingTextStyle:
          SettingsPage.titleStyle.copyWith(fontSize: 20),
    );
  }
}

class WEnumField<T extends Enum> extends StatefulWidget {
  final String name;

  /// Needed because I can't access [T.values] from here.
  final List<T> values;

  final String? subtitle;

  final T Function() getVal;

  final void Function(T p1) setVal;

  final bool Function(T? p1)? validateVal;

  final String Function(T v)? enumToString;
  const WEnumField({
    super.key,
    required this.name,
    this.subtitle,
    required this.getVal,
    required this.setVal,
    required this.values,
    this.validateVal,
    this.enumToString,
  });

  @override
  State<WEnumField> createState() => _WEnumFieldState();
}

class _WEnumFieldState<T extends Enum> extends State<WEnumField<T>> {
  String convertEnumValueToInput(T value) =>
      widget.enumToString?.call(value) ?? value.name;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.name),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: DropdownMenu<T>(
        dropdownMenuEntries: widget.values
            .map((v) => DropdownMenuEntry(
                  value: v,
                  label: convertEnumValueToInput(v),
                ))
            .toList(),
        initialSelection: widget.getVal(),
        onSelected: (value) {
          if (value != null) {
            setState(() {
              widget.setVal(value);
            });
          }
        },
      ),
    );
  }
}

// #endregion Fields
