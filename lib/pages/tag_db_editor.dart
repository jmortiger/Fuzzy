import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/models/tag_d_b.dart';

class TagDbEditorPage extends StatefulWidget {
  const TagDbEditorPage({super.key});

  @override
  State<TagDbEditorPage> createState() => _TagDbEditorPageState();
}

typedef MyEntry = TagDBEntryFull;

class _TagDbEditorPageState extends State<TagDbEditorPage> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("TagDbEditorPage").logger;
  String? data;
  List<MyEntry>? parsedData;
  Future<String?>? futureData;
  @override
  Widget build(BuildContext context) {
    Widget root;
    if (parsedData == null && data == null && futureData == null) {
      root = TextButton(
          onPressed: () => setState(() {
                futureData = tryLoadFile(logger: logger)
                  ..then((v) => setState(() {
                        data = v;
                        futureData = null;
                        if (v != null) parseAndAssign(v).ignore();
                      })).ignore();
              }),
          child: const Text("Load File"));
    } else {
      if (parsedData == null && data == null) {
        root = const CircularProgressIndicator();
      } else {
        if (futureData != null) {
          root = const CircularProgressIndicator();
        } else {
          if (parsedData == null) {
            root = const CircularProgressIndicator();
          } else {
            root = buildMain(parsedData!);
          }
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "TagDbEditorPage${parsedData != null ? ": ${parsedData!.length} entries" : ""}"),
      ),
      endDrawer: parsedData != null
          ? Drawer(
              child: ListView(
                children: [
                  TextButton(
                    onPressed: () {
                      final f = parsedData!.where((e) => e.postCount > 0);
                      setState(() {
                        parsedData = f.toList();
                      });
                    },
                    child: const Text("Remove Tags w/ 0 Posts"),
                  ),
                  TextButton(
                    onPressed: () => coarseSortByDescending(),
                    child: const Text("Coarse Sort by Count Descending"),
                  ),
                  TextButton(
                    onPressed: () => fineSortByDescending(),
                    child: const Text("Fine Sort by Count Descending"),
                  ),
                  TextButton(
                    onPressed: () => coarseSortByAscending(),
                    child: const Text("Coarse Sort by Count Ascending"),
                  ),
                  TextButton(
                    onPressed: () => fineSortByAscending(),
                    child: const Text("Fine Sort by Count Ascending"),
                  ),
                  TextButton(
                    onPressed: () {
                      int? n;
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text(
                                    "Find # of tags with this many posts"),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: double.maxFinite,
                                  child: SafeArea(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [util.numericFormatter],
                                      onChanged: (value) =>
                                          n = int.tryParse(value),
                                      onSubmitted: (value) => Navigator.pop(
                                          context, n = int.tryParse(value)),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Search"),
                                    onPressed: () => Navigator.pop(context, n),
                                  )
                                ],
                              )).then((n) {
                        if (n == null) return;
                        final lt =
                            parsedData!.where((e) => e.postCount < n).length;
                        final eq =
                            parsedData!.where((e) => e.postCount == n).length;
                        final gt =
                            parsedData!.where((e) => e.postCount > n).length;
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: SelectableText(
                                    "Out of ${parsedData!.length} posts:",
                                  ),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    height: double.maxFinite,
                                    child: SafeArea(
                                      child: SelectableText(
                                        "$lt tags w/ < $n posts (${(lt / parsedData!.length) * 100}%)\n"
                                        "$eq tags w/ exactly $n posts (${(eq / parsedData!.length) * 100}%)\n"
                                        "$gt tags w/ > $n posts (${(gt / parsedData!.length) * 100}%)\n",
                                      ),
                                    ),
                                  ),
                                )).ignore();
                      });
                    },
                    child: const Text("Profile"),
                  ),
                  TextButton(
                    onPressed: () {
                      int? n;
                      bool andLt = true;
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text(
                                    "Remove tags with this many posts"),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: double.maxFinite,
                                  child: SafeArea(
                                    child:
                                        StatefulBuilder(builder: (_, setState) {
                                      return Column(
                                        children: [
                                          TextField(
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              util.numericFormatter
                                            ],
                                            onChanged: (value) => setState(() {
                                              n = int.tryParse(value);
                                            }),
                                          ),
                                          ListTile(
                                            title:
                                                Text("And less than $n posts?"),
                                            leading: Switch(
                                              value: andLt,
                                              onChanged: (v) =>
                                                  setState(() => andLt = v),
                                            ),
                                          )
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Search"),
                                    onPressed: () => Navigator.pop(context, n),
                                  )
                                ],
                              )).then((n) {
                        if (n == null) return;
                        final r = parsedData!
                            .where(andLt
                                ? (e) => e.postCount > n
                                : (e) => e.postCount >= n)
                            .toList();
                        showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: SelectableText(
                                    "Remove ${parsedData!.length - r.length} tags?",
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text("Yes"),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                    ),
                                    TextButton(
                                      child: const Text("No"),
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                    )
                                  ],
                                )).then((v) =>
                            (v ?? false) ? setState(() => parsedData = r) : "");
                      });
                    },
                    child: const Text("Remove Tags w/ less than x posts"),
                  ),
                  TextButton(
                    onPressed: () {
                      int? n;
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title:
                                    const Text("Remove all but this many tags"),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: double.maxFinite,
                                  child: SafeArea(
                                    child:
                                        StatefulBuilder(builder: (_, setState) {
                                      return Column(
                                        children: [
                                          TextField(
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              util.numericFormatter
                                            ],
                                            onChanged: (value) => setState(() {
                                              n = int.tryParse(value);
                                            }),
                                          )
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Search"),
                                    onPressed: () => Navigator.pop(context, n),
                                  )
                                ],
                              )).then((n) {
                        if (n == null) return;
                        fineSortByDescending();
                        final r = parsedData!.take(n).toList();
                        showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: SelectableText(
                                    "Remove ${parsedData!.length - r.length} tags?",
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text("Yes"),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                    ),
                                    TextButton(
                                      child: const Text("No"),
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                    )
                                  ],
                                )).then((v) =>
                            (v ?? false) ? setState(() => parsedData = r) : "");
                      });
                    },
                    child: const Text("Remove All but x Tags"),
                  ),
                  TextButton(
                    onPressed: () {
                      compute(jsonEncode, parsedData!)
                          .then((f) => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    height: double.maxFinite,
                                    child: SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Expanded(
                                            child: SingleChildScrollView(
                                                child: SelectableText(f)),
                                          ),
                                          TextButton(
                                            onPressed: () => FileSaver.instance
                                                .saveFile(
                                                    name:
                                                        "${parsedData!.length} tags.json",
                                                    ext: "",
                                                    bytes: utf8.encode(f))
                                                .then((v) =>
                                                    Navigator.pop(context)),
                                            child: const Text("Save to file"),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ).ignore())
                          .ignore();
                    },
                    child: const Text("View as JSON"),
                  ),
                  TextButton(
                    onPressed: () => compute(jsonEncode, parsedData!).then(
                        (f) => FileSaver.instance
                            .saveFile(
                                name: "${parsedData!.length} tags.json",
                                ext: "",
                                bytes: utf8.encode(f))
                            .then((v) => Navigator.pop(context))),
                    child: const Text("Save as JSON"),
                  ),
                  TextButton(
                    onPressed: () {
                      makeEncodedCsvStringFull(parsedData!)
                          .then(
                            (f) => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: double.maxFinite,
                                  child: SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                              child: SelectableText(f)),
                                        ),
                                        TextButton(
                                          onPressed: () => FileSaver.instance
                                              .saveFile(
                                                  name:
                                                      "${parsedData!.length} tags.csv",
                                                  ext: "",
                                                  bytes: utf8.encode(f))
                                              .then((v) =>
                                                  Navigator.pop(context)),
                                          child: const Text("Save to file"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ).ignore(),
                          )
                          .ignore();
                    },
                    child: const Text("View as CSV"),
                  ),
                  TextButton(
                    onPressed: () => makeEncodedCsvStringFull(parsedData!).then(
                        (f) => FileSaver.instance
                            .saveFile(
                                name: "${parsedData!.length} tags.csv",
                                ext: "",
                                bytes: utf8.encode(f))
                            .then((v) => Navigator.pop(context))),
                    child: const Text("Save as CSV"),
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(child: root),
    );
  }

  Future<void> parseAndAssign(String data) =>
      makeTypeFromCsvString<MyEntry>(data).then((d) => setState(() {
            parsedData = d;
          }));

  Widget buildMain(List<MyEntry> parsedData) {
    return ListView.builder(
      itemBuilder: (context, i) => parsedData.elementAtOrNull(i) != null
          ? ListTile(
              title: Text("i: $i ${parsedData[i].name}"),
              subtitle: Text(parsedData[i].category.name),
              leading: Text("id: ${parsedData[i].id}"),
              trailing: Text("Count: ${parsedData[i].postCount}"),
            )
          : null,
      // itemCount: parsedData.length,//1254172 + 1000,
    );
  }

  void fineSortByDescending() => setState(() {
        parsedData!.sort((a, b) => b.postCount - a.postCount);
      });
  void coarseSortByDescending() => setState(() {
        parsedData!.sort();
      });

  void coarseSortByAscending() => setState(() {
        parsedData!.sort((a, b) => b.compareTo(a));
      });

  void fineSortByAscending() => setState(() {
        parsedData!.sort((a, b) => a.postCount - b.postCount);
      });
}

Future<String?> tryLoadFile({
//   String? dialogTitle,
//   String? initialDirectory,
//   FileType type = FileType.any,
//   List<String>? allowedExtensions,
//   dynamic Function(FilePickerStatus)? onFileLoading,
//   bool allowCompression = true,
//   int compressionQuality = 30,
//   bool allowMultiple = false,
//   bool withData = false,
//   bool withReadStream = false,
//   bool lockParentWindow = false,
//   bool readSequential = false,
// }
// {
  lm.FileLogger? logger,
  VoidCallback? afterSelectionCallback,
}) =>
    FilePicker.platform
        .pickFiles(
      dialogTitle: "Select .csv or .txt file",
      allowedExtensions: ["csv", "txt"],
      type: FileType.custom,
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
