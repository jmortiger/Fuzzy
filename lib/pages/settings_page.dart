import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:j_util/j_util_full.dart';

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
                content: Text("Saved!"),
                action: SnackBarAction(
                  label: "See Contents",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          content: SelectableText(v),
                        );
                      },
                    );
                  },
                ),
              ));
            }),
            child: const Text("Save Settings"),
          ),
          TextButton(
            onPressed: () => settings.loadFromFile().then((v) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Loaded from file!"),
              ));
            }),
            child: const Text("Load Settings"),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("General Settings"),
            titleTextStyle: SettingsPage.titleStyle,
          ),
          // _constructStringSetField(
          // context,
          SetStringField(
            name: "Favorite Tags",
            // getVal: () => settings.favoriteTags,
            getVal: settings.favoriteTags,
            setVal: (Set<String> v) => settings.favoriteTags = v,
            // validateVal: (Set<String> v) => settings.favoriteTags = v,
          ),
          // _constructStringSetField(
          //   context,
          //   getVal: () => settings.blacklistedTags,
          SetStringField(
            getVal: settings.blacklistedTags,
            name: "Blacklisted Tags",
            setVal: (Set<String> v) => settings.blacklistedTags = v,
            // validateVal: (Set<String> v) => settings.blacklistedTags = v,
          ),
          ListTile(
            title: const Text("Search View Settings"),
            titleTextStyle: SettingsPage.titleStyle,
          ),
          WIntegerField(
            // _constructIntegerField(
            //   context,
            getVal: () => settings.searchView.postsPerRow,
            // getVal: settings.searchView.postsPerRow,
            name: "Posts per row",
            setVal: (int val) => settings.searchView.postsPerRow = val,
            validateVal: (int? val) => (val ?? -1) >= 0,
          ),
          WIntegerField(
            // _constructIntegerField(
            //   context,
            getVal: () => settings.searchView.postsPerPage,
            // getVal: settings.searchView.postsPerPage,
            name: "Posts per page",
            setVal: (int val) => settings.searchView.postsPerPage = val,
            validateVal: (int? val) => (val ?? -1) >= 0,
          ),
        ],
      ),
    );
  }

  /* ListTile _constructIntegerField(
    BuildContext context, {
    required String name,
    required int Function() getVal,
    required void Function(int) setVal,
    bool Function(int?)? validateVal,
  }) {
    return ListTile(
      key: ValueKey(getVal()),
      title: Text(name),
      trailing: Text(getVal().toString()),
      leadingAndTrailingTextStyle:
          const DefaultTextStyle.fallback().style.copyWith(
                fontSize: 20,
                color: Colors.white,
              ),
      onTap: () {
        final before = getVal();
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
            print("Before: ${getVal()}");
            setVal(value!);
            print("After: ${getVal()}");
          }
        }).onError((error, stackTrace) => print(error));
      },
    );
  } */

  /* ListTile _constructStringSetField(
    BuildContext context, {
    required String name,
    required Set<String> Function() getVal,
    required void Function(Set<String>) setVal,
    bool Function(Set<String>?)? validateVal,
  }) {
    return ListTile(
      key: ValueKey(getVal()),
      title: Text(name),
      subtitle: Text(getVal().toString()),
      onTap: () {
        final before = getVal().fold(
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
              print("Before: ${getVal().toString()}");
              if (getVal().isNotEmpty) {
                getVal().clear();
              }
              setVal(getVal()
                ..addAll(value
                    .split(RegExpExt.whitespace)
                    .where((s) => s.isNotEmpty)));
              print("After: ${getVal().toString()}");
            }
          },
        ).onError((error, stackTrace) => print(error));
      },
    );
  } */
}

class SetStringField extends StatefulWidget {
  final String name;

  final Set<String> getVal;

  final void Function(Set<String> p1) setVal;

  final bool Function(Set<String>? p1)? validateVal;
  const SetStringField({
    super.key,
    required this.name,
    required this.getVal,
    required this.setVal,
    this.validateVal,
  });

  @override
  State<SetStringField> createState() => _SetStringFieldState();
}

class _SetStringFieldState extends State<SetStringField> {
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
          const DefaultTextStyle.fallback().style.copyWith(
                fontSize: 20,
                color: Colors.white,
              ),
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
