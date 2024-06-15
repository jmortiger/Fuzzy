import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/app_settings.dart';
import 'package:j_util/j_util_full.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  AppSettings get settings => AppSettings.i;
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
          const TextButton(onPressed: null, child: Text("Save Settings")),
          const TextButton(onPressed: null, child: Text("Load Settings")),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("General Settings"),
            titleTextStyle: SettingsPage.titleStyle,
          ),
          // _buildFavTags(context),
          _constructStringSetField(
            context,
            name: "Favorite Tags",
            getVal: () => settings.favoriteTags,
            setVal: (Set<String> v) => settings.favoriteTags = v,
            // validateVal: (Set<String> v) => settings.favoriteTags = v,
          ),
          _constructStringSetField(
            context,
            name: "Blacklisted Tags",
            getVal: () => settings.blacklistedTags,
            setVal: (Set<String> v) => settings.blacklistedTags = v,
            // validateVal: (Set<String> v) => settings.blacklistedTags = v,
          ),
          ListTile(
            title: const Text("Search View Settings"),
            titleTextStyle: SettingsPage.titleStyle,
          ),
          _constructIntegerField(
            context,
            name: "Posts per row",
            getVal: () => settings.searchView.postsPerRow,
            setVal: (int val) => settings.searchView.postsPerRow = val,
            validateVal: (int? val) => (val ?? -1) >= 0,
          ),
          _constructIntegerField(
            context,
            name: "Posts per page",
            getVal: () => settings.searchView.postsPerPage,
            setVal: (int val) => settings.searchView.postsPerPage = val,
            validateVal: (int? val) => (val ?? -1) >= 0,
          ),
        ],
      ),
    );
  }

  ListTile _constructIntegerField(
    BuildContext context, {
    required String name,
    required int Function() getVal,
    required void Function(int) setVal,
    bool Function(int?)? validateVal,
  }) {
    return ListTile(
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
                  onPressed: () => Navigator.pop(context, -1),
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
  }

  ListTile _constructStringSetField(
    BuildContext context, {
    required String name,
    required Set<String> Function() getVal,
    required void Function(Set<String>) setVal,
    bool Function(Set<String>?)? validateVal,
  }) {
    return ListTile(
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
                  onPressed: () => Navigator.pop(context, ""),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        ).then<void>(
          (value) {
            if (value?.isNotEmpty ?? false) {
              print("Before: ${getVal().toString()}");
              if (getVal().isNotEmpty) {
                getVal().clear();
              }
              setVal(getVal()..addAll(value!.split("\n")));
              print("After: ${getVal().toString()}");
            }
          },
        ).onError((error, stackTrace) => print(error));
      },
    );
  }

  // ListTile _buildFavTags(BuildContext context) {
  //   return ListTile(
  //     title: const Text("Favorite Tags"),
  //     subtitle: Text(settings.favoriteTags.toString()),
  //     onTap: () {
  //       final before = settings.favoriteTags.fold(
  //         "",
  //         (previousValue, element) => "$previousValue$element\n",
  //       );
  //       var t = before;
  //       showDialog<String>(
  //         context: context,
  //         builder: (context) {
  //           return AlertDialog(
  //             content: TextField(
  //               maxLines: null,
  //               onChanged: (value) {
  //                 t = value;
  //               },
  //               onSubmitted: (value) {
  //                 t = value;
  //               },
  //               controller: TextEditingController.fromValue(
  //                 TextEditingValue(
  //                   text: t,
  //                   selection: TextSelection(
  //                     baseOffset: 0,
  //                     extentOffset: t.length - 1,
  //                   ),
  //                 ),
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context, t),
  //                 child: const Text("Accept"),
  //               ),
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context, ""),
  //                 child: const Text("Cancel"),
  //               ),
  //             ],
  //           );
  //         },
  //       ).then<void>(
  //         (value) {
  //           if (value?.isNotEmpty ?? false) {
  //             print("Before: ${settings.favoriteTags.toString()}");
  //             if (settings.favoriteTags.isNotEmpty) {
  //               settings.favoriteTags.clear();
  //             }
  //             settings.favoriteTags.addAll(value!.split("\n"));
  //             print("After: ${settings.favoriteTags.toString()}");
  //           }
  //         },
  //       ).onError((error, stackTrace) => print(error));
  //     },
  //   );
  // }
}
