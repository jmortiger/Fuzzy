import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_searches.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:j_util/j_util_full.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("SettingsPage");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

class SettingsPage extends StatelessWidget {
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

class WNonFoldOutSettings extends StatelessWidget {
  const WNonFoldOutSettings({
    super.key,
  });

  TextStyle get titleStyle => SettingsPage.titleStyle;

  AppSettings get settings => AppSettings.i!;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text("General Settings"),
          titleTextStyle: SettingsPage.titleStyle,
        ),
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
          title: const Text("Search View Settings"),
          titleTextStyle: SettingsPage.titleStyle,
        ),
        WIntegerField(
          getVal: () => AppSettings.i!.searchView.postsPerRow,
          name: "Posts per row",
          setVal: (int val) => AppSettings.i!.searchView.postsPerRow = val,
          validateVal: (int? val) => (val ?? -1) >= 0,
        ),
        WIntegerField(
          getVal: () => AppSettings.i!.searchView.postsPerPage,
          name: "Posts per page",
          setVal: (int val) => AppSettings.i!.searchView.postsPerPage = val,
          validateVal: (int? val) => (val ?? -1) >= 0,
        ),
        WEnumListField<PostInfoPaneItem>.getter(
          name: "Posts per page",
          getter: () => AppSettings.i!.searchView.postInfoBannerItems,
          setVal: (/* List<PostInfoPaneItem>  */ val) => AppSettings
              .i!.searchView.postInfoBannerItems = val.cast<PostInfoPaneItem>(),
          values: PostInfoPaneItem.values,
        ),
        ListTile(
          title: const Text("Post View Settings"),
          titleTextStyle: SettingsPage.titleStyle,
        ),
        WBooleanField(
          name: "Force High Quality Image",
          getVal: () => settings.postView.forceHighQualityImage,
          setVal: (p1) => AppSettings.i!.postView.forceHighQualityImage = p1,
        ),
        WBooleanField(
          name: "Allow Overflow",
          getVal: () => settings.postView.allowOverflow,
          setVal: (p1) => AppSettings.i!.postView.allowOverflow = p1,
        ),
        WBooleanField(
          name: "Color Tag Headers",
          getVal: () => settings.postView.colorTagHeaders,
          setVal: (p1) => AppSettings.i!.postView.colorTagHeaders = p1,
        ),
        WBooleanField(
          name: "Color Tags",
          getVal: () => settings.postView.colorTags,
          setVal: (p1) => AppSettings.i!.postView.colorTags = p1,
        ),
        WBooleanField(
          name: "Autoplay Video",
          getVal: () => settings.postView.autoplayVideo,
          setVal: (p1) => AppSettings.i!.postView.autoplayVideo = p1,
        ),
        WBooleanField(
          name: "Start video muted",
          getVal: () => settings.postView.startVideoMuted,
          setVal: (p1) => AppSettings.i!.postView.startVideoMuted = p1,
        ),
        WBooleanField(
          name: "Show time left",
          subtitle:
              "When playing a video, show the time remaining instead of the total duration?",
          getVal: () => settings.postView.showTimeLeft,
          setVal: (p1) => AppSettings.i!.postView.showTimeLeft = p1,
        ),
      ],
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
            const ListTile(
              title: Text("Clear Cached Searches"),
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
                getVal: () => AppSettings.i!.searchView.postsPerRow,
                name: "Posts per row",
                setVal: (num val) => SearchView.i.postsPerRow = val.toInt(),
                validateVal: (num? val) => (val?.toInt() ?? -1) >= 0,
                defaultValue: SearchViewData.defaultData.postsPerRow,
                divisions: SearchViewData.postsPerRowBounds.max -
                    SearchViewData.postsPerRowBounds.min,
              ),
              WIntegerField(
                getVal: () => AppSettings.i!.searchView.postsPerRow,
                name: "Posts per row",
                setVal: (int val) =>
                    AppSettings.i!.searchView.postsPerRow = val,
                validateVal: (int? val) => (val ?? -1) >= 0,
              ),
              WIntegerField(
                getVal: () => AppSettings.i!.searchView.postsPerPage,
                name: "Posts per page",
                setVal: (int val) =>
                    AppSettings.i!.searchView.postsPerPage = val,
                validateVal: (int? val) => (val ?? -1) >= 0,
              ),
              WEnumListField<PostInfoPaneItem>.getter(
                name: "Posts per page",
                getter: () => AppSettings.i!.searchView.postInfoBannerItems,
                setVal: (/* List<PostInfoPaneItem>  */ val) => AppSettings
                    .i!
                    .searchView
                    .postInfoBannerItems = val.cast<PostInfoPaneItem>(),
                values: PostInfoPaneItem.values,
              ),
              ListTile(
                title: const Text("Toggle Image Display Method"),
                onTap: () {
                  print("Before: ${imageFit.name}");
                  setState(() {
                    imageFit = imageFit == BoxFit.contain
                        ? BoxFit.cover
                        : BoxFit.contain;
                  });
                  print("After: ${imageFit.name}");
                  // Navigator.pop(context);
                },
                trailing: Text(imageFit.name),
              ),
            ]),
        ExpansionTile(
          title: Text(
            "Post View Settings",
            style: SettingsPage.titleStyle,
          ),
          children: [
            WBooleanField(
              name: "Default to High Quality Image",
              subtitle: "If the selected quality is unavailable, use the highest quality.",
              getVal: () => settings.postView.forceHighQualityImage,
              setVal: (p1) =>
                  AppSettings.i!.postView.forceHighQualityImage = p1,
            ),
            ListTile(
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
            ),
            WBooleanField(
              name: "Allow Overflow",
              getVal: () => settings.postView.allowOverflow,
              setVal: (p1) => AppSettings.i!.postView.allowOverflow = p1,
            ),
            WBooleanField(
              name: "Color Tag Headers",
              getVal: () => settings.postView.colorTagHeaders,
              setVal: (p1) => AppSettings.i!.postView.colorTagHeaders = p1,
            ),
            WBooleanField(
              name: "Color Tags",
              getVal: () => settings.postView.colorTags,
              setVal: (p1) => AppSettings.i!.postView.colorTags = p1,
            ),
            WBooleanField(
              name: "Autoplay Video",
              getVal: () => settings.postView.autoplayVideo,
              setVal: (p1) => AppSettings.i!.postView.autoplayVideo = p1,
            ),
            WBooleanField(
              name: "Start video muted",
              getVal: () => settings.postView.startVideoMuted,
              setVal: (p1) => AppSettings.i!.postView.startVideoMuted = p1,
            ),
            WBooleanField(
              name: "Show time left",
              subtitle: "When playing a video, show the time "
                  "remaining instead of the total duration?",
              getVal: () => settings.postView.showTimeLeft,
              setVal: (p1) => AppSettings.i!.postView.showTimeLeft = p1,
            ),
            WBooleanField(
              name: "Start With Tags Expanded",
              getVal: () => settings.postView.startWithTagsExpanded,
              setVal: (p) => AppSettings.i!.postView.startWithTagsExpanded = p,
            ),
            WBooleanField(
              name: "Start With Description Expanded",
              getVal: () => settings.postView.startWithDescriptionExpanded,
              setVal: (p) =>
                  AppSettings.i!.postView.startWithDescriptionExpanded = p,
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
          (e, index, list) =>
              widget.stringToEnum?.call(e) ??
              widget.values.singleWhere((v) => v.name == e),
        );
  }

  String convertValueToInput(List<T> value) {
    return value.fold(
      "",
      (acc, e) => "$acc${widget.enumToString?.call(e) ?? e.name}\n",
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(getVal),
      title: Text(name),
      subtitle: Text(getVal.toString()),
      onTap: () {
        final before = convertValueToInput(getVal);
        var t = before;
        validation(String value) {
          validateVal?.call(convertInputToValue(value)) ?? true
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
              print("_EnumListFieldState: Before: ${getVal.toString()}");
              setState(() {
                setVal(convertInputToValue(value));
              });
              print("_EnumListFieldState: After: ${getVal.toString()}");
            }
          },
        ).onError((error, stackTrace) => print(error));
      },
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

  final int Function() getVal;

  final void Function(int p1) setVal;

  final bool Function(int? p1)? validateVal;
  const WIntegerField({
    super.key,
    required this.name,
    required this.getVal,
    required this.setVal,
    this.validateVal,
  });

  @override
  State<WIntegerField> createState() => _WIntegerFieldState();
}

class _WIntegerFieldState extends State<WIntegerField> {
  String get name => widget.name;

  int get getVal => widget.getVal();

  void Function(int p1) get setVal => widget.setVal;

  bool Function(int? p1)? get validateVal => widget.validateVal;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(getVal),
      title: Text(name),
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
                      extentOffset: t.length - 1,
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
            print("Before: ${getVal}");
            setState(() {
              setVal(value!);
            });
            print("After: ${getVal}");
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

// #endregion Fields