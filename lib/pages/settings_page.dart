import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;

// #region Logger
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;
// ignore: unnecessary_late
late final lRecord = lm.genLogger("SettingsPage");
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
              print(v);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text("Saved!"),
                action: SnackBarAction(
                  label: "See Contents",
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: SelectableText(
                        "Saved: $v\nValue: ${jsonEncode(
                          settings.toJson(),
                        )}",
                      ),
                    ),
                  ),
                ),
              ));
            }),
            child: const Text("Save Settings"),
          ),
          TextButton(
            onPressed: () => settings.loadFromFile().then((v) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text("Loaded from file!"),
                action: SnackBarAction(
                  label: "See Contents",
                  onPressed: () => showDialog(
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
                  ),
                ),
              ));
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
              getVal: AppSettings.i!.favoriteTags,
              setVal: (Set<String> v) => AppSettings.i!.favoriteTags = v,
            ),
            WSetStringField(
              getVal: AppSettings.i!.blacklistedTags,
              name: "Blacklisted Tags",
              setVal: (Set<String> v) => AppSettings.i!.blacklistedTags = v,
            ),
            ListTile(
              title: const Text("Clear Cached Searches"),
              subtitle:
                  Text("Delete all ${CachedSearches.searches.length} searches"),
              onTap: CachedSearches.clear,
            )
          ],
        ),
        ExpansionTile(
            title: Text(
              "Search View Settings",
              style: SettingsPage.titleStyle,
            ),
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
              ),
              WIntegerField(
                getVal: () => SearchView.i.postsPerRow,
                name: "Posts per row",
                setVal: (int val) => SearchView.i.postsPerRow = val,
                validateVal: (int? val) => (val ?? -1) >= 0,
              ),
              WIntegerField(
                getVal: () => SearchView.i.postsPerPage,
                name: "Posts per page",
                setVal: (int val) => SearchView.i.postsPerPage = val,
                validateVal: (int? val) => (val ?? -1) >= 0,
              ),
              WIntegerField(
                getVal: () => (SearchView.i.widthToHeightRatio * 100).toInt(),
                name: "Width to height ratio",
                setVal: (int val) =>
                    SearchView.i.widthToHeightRatio = val / 100,
                // validateVal: (int? val) => (val ?? -1) >= 0,
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
                  logger.finest("Before: ${imageFit.name}");
                  setState(() {
                    imageFit = imageFit == BoxFit.contain
                        ? BoxFit.cover
                        : BoxFit.contain;
                  });
                  logger.finer("After: ${imageFit.name}");
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
              WIntegerField(
                getVal: () => SearchView.i.numSavedSearchesInSearchBar,
                name: "# of prior searches in search bar",
                subtitle: "Limits the # of prior searches in the search "
                    "bar's suggestions to prevent it from clogging results",
                setVal: (int val) =>
                    SearchView.i.numSavedSearchesInSearchBar = val,
                validateVal: (int? val) => (val ?? -1) >= 0,
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
                subtitle: 'Wherever possible, search using a set\'s shortname instead its id (e.g. "set:my_set" over "set:123"). This will break saved searches if the shortname changes.',
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
            /* ListTile(
              title: const Text("Toggle Image Quality"),
              onTap: () {
                print("Before: ${PostView.i.imageQuality}");
                setState(() {
                  PostView.i.imageQuality = PostView.i.imageQuality == "low"
                      ? "medium"
                      : PostView.i.imageQuality == "medium"
                          ? "high"
                          : "low";
                });
                print("After: ${PostView.i.imageQuality}");
                // Navigator.pop(context);
              },
              trailing: Text(PostView.i.imageQuality),
            ), */
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
  });

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
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
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
  void onChanged([bool? value]) =>
      widget.validateVal?.call(value) ?? true
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

  final Set<String> getVal;

  final void Function(Set<String> p1) setVal;

  final bool Function(Set<String>? p1)? validateVal;
  const WSetStringField({
    super.key,
    required this.name,
    required this.getVal,
    required this.setVal,
    this.validateVal,
  });

  @override
  State<WSetStringField> createState() => _WSetStringFieldState();
}

class _WSetStringFieldState extends State<WSetStringField> {
  String get name => widget.name;

  Set<String> get getVal => widget.getVal;

  void Function(Set<String> p1) get setVal => widget.setVal;

  bool Function(Set<String>? p1)? get validateVal => widget.validateVal;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(getVal),
      title: Text(name),
      subtitle: Text(getVal.toString()),
      onTap: () {
        final before = getVal.fold(
          "",
          (previousValue, element) => "$previousValue$element\n",
        );
        var t = before;
        validation(String value) {
          validateVal?.call(
                    value.split(RegExpExt.whitespace).toSet(),
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
              print("Before: ${getVal.toString()}");
              if (getVal.isNotEmpty) {
                getVal.clear();
              }
              setState(() {
                setVal(getVal
                  ..addAll(value
                      .split(RegExpExt.whitespace)
                      .where((s) => s.isNotEmpty)));
              });
              print("After: ${getVal.toString()}");
            }
          },
        ).onError((error, stackTrace) => print(error));
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
    return input
        .split(RegExpExt.whitespace)
        .where((s) => s.isNotEmpty)
        .mapAsList(
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
              logger.finer("_EnumListFieldState: Before: ${getVal.toString()}");
              setState(() {
                setVal(value);
              });
              logger.fine("_EnumListFieldState: After: ${getVal.toString()}");
            }
          },
        ).onError(
            (error, stackTrace) => logger.severe(error, error, stackTrace));
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

  final void Function(int p1) setVal;

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

  void Function(int p1) get setVal => widget.setVal;

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
      onTap: () {
        final before = getVal;
        var t = before.toString();
        validation(String value) {
          (validateVal?.call(int.tryParse(value)) ?? true) ? t = value : null;
        }

        showDialog<int>(
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
                  Navigator.pop(context, int.parse(t));
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
                  onPressed: () => Navigator.pop(context, int.parse(t)),
                  child: const Text("Accept"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        ).then<void>((value) {
          if (validateVal?.call(value) ?? value != null) {
            print("Before: $getVal");
            setState(() {
              setVal(value!);
            });
            print("After: $getVal");
            print(jsonEncode(AppSettings.i));
          }
        }).onError((error, stackTrace) => print(error));
      },
    );
  }
}

class WNumSliderField<T extends num> extends StatefulWidget {
  final String name;

  final String? subtitle;

  final T Function() getVal;

  final void Function(num p1) setVal;

  final bool Function(num? p1)? validateVal;

  final T min;

  final T max;

  final T? defaultValue;

  final int? divisions;
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
  });

  @override
  State<WNumSliderField> createState() => _WNumSliderFieldState();
}

class _WNumSliderFieldState<T extends num> extends State<WNumSliderField<T>> {
  String get name => widget.name;

  T get getVal => widget.getVal();

  void Function(num p1) get setVal => widget.setVal;

  bool Function(num? p1)? get validateVal => widget.validateVal;

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

  @override
  Widget build(BuildContext context) {
    // var t = T;
    // logger.severe(t);
    return ListTile(
      key: ValueKey(getVal),
      title: Row(children: [
        Text(name),
        Slider(
          label: getVal.toString(),
          value: getVal.toDouble(),
          onChanged: (v) => (validateVal?.call(v) ?? true)
              ? setState(() => setVal(tempValue = v))
              : setState(() {
                  tempValue = v;
                }),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          secondaryTrackValue: widget.defaultValue?.toDouble(),
          divisions: divisions,
          // onChangeStart: (value) => ,
          // onChangeEnd: (v) => ,
          // allowedInteraction: SliderInteraction.tapAndSlide,
        )
      ]),
      subtitle: widget.subtitle != null ? Text(widget.subtitle!) : null,
      trailing: Text(getVal.toString()),
      leadingAndTrailingTextStyle:
          SettingsPage.titleStyle.copyWith(fontSize: 20),
      // onTap: () {
      //   final before = getVal;
      //   var t = before.toString();
      //   validation(String value) {
      //     (validateVal?.call(num.tryParse(value)) ?? true) ? t = value : null;
      //   }

      //   showDialog<num>(
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
      //                 extentOffset: t.length - 1,
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
      //   ).then<void>((value) {
      //     if (validateVal?.call(value) ?? value != null) {
      //       print("Before: ${getVal}");
      //       setState(() {
      //         setVal(value!);
      //       });
      //       print("After: ${getVal}");
      //       print(jsonEncode(AppSettings.i));
      //     }
      //   }).onError((error, stackTrace) => print(error));
      // },
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