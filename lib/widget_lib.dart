import 'dart:convert' as dc;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/settings_page.dart' show SettingsPage;
import 'package:fuzzy/util/util.dart' as util show spinnerFitted;
import 'package:j_util/collections.dart' show ListIterators;

export 'package:fuzzy/widgets/post_grid.dart';
export 'package:fuzzy/widgets/user_identifier.dart';
export 'package:fuzzy/widgets/w_comments_pane.dart';
export 'package:fuzzy/widgets/w_d_text_preview.dart';
export 'package:fuzzy/widgets/w_expansion_tile_async.dart'
    show ExpansionTileAsync;
export 'package:fuzzy/widgets/w_fab_builder.dart';
export 'package:fuzzy/widgets/w_home_end_drawer.dart';
export 'package:fuzzy/widgets/w_image_result.dart';
export 'package:fuzzy/widgets/w_page_indicator.dart';
export 'package:fuzzy/widgets/w_page_view_async_builder.dart';
export 'package:fuzzy/widgets/w_post_search_results.dart';
export 'package:fuzzy/widgets/w_post_thumbnail.dart';
export 'package:fuzzy/widgets/w_search_bar.dart';
export 'package:fuzzy/widgets/w_search_pool.dart';
export 'package:fuzzy/widgets/w_search_set.dart';
export 'package:fuzzy/widgets/w_update_set.dart';
export 'package:fuzzy/widgets/w_upvote_button.dart';
export 'package:fuzzy/widgets/w_video_player_screen.dart';
export 'package:j_util/j_util_widgets.dart' hide Builder;

// #region Logger
lm.Printer get _print => _lRecord.print;
lm.FileLogger get _logger => _lRecord.logger;
// ignore: unnecessary_late
late final _lRecord = lm.generateLogger("WidgetLib");
// #endregion Logger

// #region Fields

class WBooleanField extends StatefulWidget {
  final String name;
  final String? subtitle;
  final String Function()? subtitleBuilder;
  final bool Function() getVal;
  final void Function(bool p1) setVal;
  final bool Function(bool? p1)? validateVal;
  final bool useSwitch;

  const WBooleanField({
    super.key,
    required this.name,
    this.subtitle,
    required this.getVal,
    required this.setVal,
    // required this.settings,
    this.validateVal,
    this.useSwitch = true,
  }) : subtitleBuilder = null;
  const WBooleanField.subtitleBuilder({
    super.key,
    required this.name,
    this.subtitleBuilder,
    required this.getVal,
    required this.setVal,
    // required this.settings,
    this.validateVal,
    this.useSwitch = true,
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
      trailing: widget.useSwitch
          ? Switch(
              value: widget.getVal(),
              onChanged: onChanged,
            )
          : Checkbox(
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
  bool? cycle(bool? value) => switch (value) {
        false => true,
        true => null,
        null => false,
      };
  void onChanged([bool? value]) =>
      widget.validateVal?.call(value ?? cycle(widget.getVal())) ?? true
          ? setState(() => widget.setVal(value ?? cycle(widget.getVal())))
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
    return input
        .split(RegExp(r"\s"))
        .where((s) => s.isNotEmpty)
        .map((e) => convertInputToEnumValue(e))
        .toList();
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
        (e, i, _) => ListTile(
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

class WEnumSetField<T extends Enum> extends StatefulWidget {
  final String name;

  /// Either this or [getter] are required.
  final Set<T>? getVal;

  /// Either this or [getVal] are required.
  final Set<T> Function()? getter;

  final void Function(Set /* <T> */ p1) setVal;

  final bool Function(Set<T>? p1)? validateVal;

  /// Needed because I can't access [T.values] from here.
  final Set<T> values;

  final String Function(T v)? enumToString;

  final T Function(String v)? stringToEnum;
  // const WEnumSetField({
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
  const WEnumSetField.getter({
    super.key,
    required this.name,
    required this.getter,
    required this.setVal,
    this.validateVal,
    required this.values,
    this.enumToString,
    this.stringToEnum,
  }) : getVal = null;
  const WEnumSetField.value({
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
  State<WEnumSetField> createState() => _WEnumSetFieldState();
}

class _WEnumSetFieldState<T extends Enum> extends State<WEnumSetField<T>> {
  String get name => widget.name;

  Set<T> get getVal =>
      widget.getVal ??
      widget.getter?.call() ??
      (throw StateError(
        "Either widget.getVal or widget.getter must be a non-null value",
      ));

  Function get setVal => widget.setVal;

  bool Function(Set<T>? p1)? get validateVal => widget.validateVal;

  Set<T> convertInputToValue(String input) => input
      .split(RegExp(r"\s"))
      .where((s) => s.isNotEmpty)
      .map((e) => convertInputToEnumValue(e))
      .toSet();

  String convertValueToInput(Set<T> value) {
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
  late Set<T> temp;
  @override
  void initState() {
    super.initState();
    temp = Set.of(getVal);
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
        showDialog<Set<T>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              // content: _buildTextEntry(t),
              content: SizedBox(
                width: double.maxFinite,
                height: double.maxFinite,
                child: WEnumSetFieldContent(
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
              _logger.finer("_EnumSetFieldState: Before: ${getVal.toString()}");
              setState(() {
                setVal(value);
              });
              _logger.fine("_EnumSetFieldState: After: ${getVal.toString()}");
            }
          },
        ).onError(
            (error, stackTrace) => _logger.severe(error, error, stackTrace));
      },
    );
  }
}

/// Abuses reference to [initialState] to send data back.
class WEnumSetFieldContent<T extends Enum> extends StatefulWidget {
  final Set<T> initialState;

  /// Needed because I can't access [T.values] from here.
  final Set<T> values;

  final String Function(T v)? enumToString;

  const WEnumSetFieldContent({
    super.key,
    required this.initialState,
    required this.values,
    this.enumToString,
  });

  @override
  State<WEnumSetFieldContent> createState() => _WEnumSetFieldContentState();
}

class _WEnumSetFieldContentState<T extends Enum>
    extends State<WEnumSetFieldContent<T>> {
  /* late  */ Set<T> get temp => widget.initialState;
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
      children: temp
          .map(
        (e) => ListTile(
          // leading: Text(i.toString()),
          leading: IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => setState(() => temp.remove(e)),
          ),
          title: DropdownMenu<T>(
            dropdownMenuEntries: widget.values
                .difference(temp)
                .map((v) => DropdownMenuEntry(
                      value: v,
                      label: convertEnumValueToInput(v),
                    ))
                .followedBy([
              DropdownMenuEntry(
                value: e,
                label: convertEnumValueToInput(e),
              )
            ]).toList(),
            initialSelection: e,
            onSelected: (value) {
              if (value != null && value != e) {
                setState(() => temp
                  ..remove(e)
                  ..add(value));
              }
            },
          ),
        ),
      )
          .followedBy([
        if (widget.values.difference(temp).isNotEmpty)
          ListTile(
            title: const Text("Add"),
            onTap: () => setState(() {
              temp.add(widget.values.difference(temp).first);
            }),
          )
      ]).toList(),
    );
  }
}

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
          _print(dc.jsonEncode(AppSettings.i));
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
            _logger.fine(dc.jsonEncode(AppSettings.i));
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

void Function() buildNumericalEntryDialog<T extends num>({
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

class SimpleFutureBuilder<T> extends StatefulWidget {
  final Future<T> future;
  final Widget beforeCompletionChild;
  final Widget Function(BuildContext context, T result) afterCompletionBuilder;
  final void Function(BuildContext context, T result)? onCompletionCallback;
  final Widget Function(BuildContext context, Object? e, StackTrace s)?
      onErrorBuilder;

  /// Called immediately on the error occurring
  final void Function(Object? e, StackTrace s)? onErrorCallback;

  /// Called immediately on the error occurring
  final T Function(Object? e, StackTrace s)? onErrorHandler;
  final bool Function(Object e)? onErrorHandlerTest;
  /* final bool Function(BuildContext context, Object? e, StackTrace s)?
      hideOnErrorCallback; */
  // final bool? hideWidgetOnError;
  final lm.LogLevel? level;
  final lm.FileLogger? logger;
  const SimpleFutureBuilder({
    super.key,
    required this.future,
    this.beforeCompletionChild = util.spinnerFitted,
    required this.afterCompletionBuilder,
    this.onCompletionCallback,
    this.onErrorBuilder,
    this.onErrorCallback,
    /* this.onErrorHandler,
    this.onErrorHandlerTest, */
    // this.hideOnErrorCallback,
    // this.hideWidgetOnError,
    this.level,
    this.logger,
  })  : onErrorHandler = null,
        onErrorHandlerTest = null;

  @override
  State<SimpleFutureBuilder<T>> createState() => _SimpleFutureBuilderState<T>();
}

class _SimpleFutureBuilderState<T> extends State<SimpleFutureBuilder<T>> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("SimpleFutureBuilder").logger;
  late T result;
  bool isDone = false;
  bool hasError = false;
  late Object? e;
  late StackTrace s;
  Future? f;
  @override
  void initState() {
    super.initState();
    f = ((widget.onErrorHandler != null
            ? widget.future.onError(
                widget.onErrorHandler!,
                test: widget.onErrorHandlerTest,
              )
            : widget.future)
          // ignore: use_build_context_synchronously
          ..then((v) => widget.onCompletionCallback?.call(context, v)))
        .then((v) {
      setState(() {
        isDone = true;
        result = v;
        f?.ignore();
        f = null;
      });
    }).onError(
      (error, stackTrace) {
        widget.onErrorCallback?.call(error, stackTrace);
        setState(() {
          e = error;
          s = stackTrace;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) => isDone
      ? hasError
          ? widget.onErrorBuilder?.call(context, e, s) ??
              (e is FlutterError
                  ? ErrorWidget.withDetails(
                      message: (e as FlutterError).message,
                      error: (e as FlutterError),
                    )
                  : ErrorPage.makeConst(
                      error: e,
                      stackTrace: s,
                      isFullPage: false,
                    ))
          : widget.afterCompletionBuilder(context, result)
      : widget.beforeCompletionChild;
}
