import 'package:flutter/material.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:provider/provider.dart';

class SavedSearchesPageProvider extends StatelessWidget {
  const SavedSearchesPageProvider({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SavedDataE6.$Copy,
      builder: (context, child) => Consumer<SavedDataE6>(
        builder: (context, value, child) => SavedSearchesPageSingleton(
          data: value,
          // key: ObjectKey(value),
        ),
      ),
    );
  }
}

class SavedSearchesPageSingleton extends StatefulWidget {
  final SavedDataE6? data;

  const SavedSearchesPageSingleton({super.key, this.data});

  @override
  State<SavedSearchesPageSingleton> createState() =>
      _SavedSearchesPageSingletonState();
}

class _SavedSearchesPageSingletonState
    extends State<SavedSearchesPageSingleton> {
  var data = LateInstance<SavedDataE6>();
  @override
  void initState() {
    if (widget.data != null) {
      data.$ = widget.data!;
    } else {
      // if (Platform.isWeb) {
      //   switch (SavedDataE6.$Async) {
      //     case Future<SavedDataE6> t:
      //       print("async");
      //       t.then(
      //         (v) {
      //           setState(() {
      //             data.$ = v;
      //           });
      //         },
      //       ).onError(util.defaultOnError);
      //       break;
      //     case SavedDataE6 t:
      //       print("sync");
      //       data.$ = t;
      //       break;
      //   }
      // } else {
      //   SavedDataE6.fileFullPath
      //       .getItem()
      //       .then((v) => Storable.loadToInstanceAsync<SavedDataE6>(v))
      //       .then((v) => data.$ = v);
      // }
      switch (SavedDataE6.$Async) {
        case Future<SavedDataE6> t:
          print("async");
          t.then(
            (v) {
              setState(() {
                data.$ = v;
              });
            },
          ).onError(util.defaultOnError);
          break;
        case SavedDataE6 t:
          print("sync");
          data.$ = t;
          break;
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Searches"),
      ),
      endDrawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text("TGH"),
            ),
            ListTile(
              title: const Text("Add Saved Search"),
              onTap: () {
                showSavedElementEditDialogue(
                  context,
                ).then((value) {
                  if (value != null) {
                    data.$.addAndSaveSearch(
                      SavedSearchData.fromTagsString(
                        tags: value.mainData,
                        title: value.title,
                        uniqueId: value.uniqueId ?? "",
                        parent: value.parent ?? "",
                      ),
                    );
                  }
                });
              },
            ),
            // ListTile(
            //   title: const Text("Add Saved Pool"),
            //   onTap: () {
            //     showSavedElementEditDialogue(
            //       context,
            //       mainDataName: "Pool Id",
            //       isNumeric: true,
            //     ).then((value) {
            //       if (value != null) {
            //         data.$.addAndSavePool(
            //           SavedPoolData(
            //             id: int.parse(value.mainData),
            //             title: value.title,
            //           ),
            //         );
            //       }
            //     });
            //   },
            // ),
            // ListTile(
            //   title: const Text("Add Saved Set"),
            //   onTap: () {
            //     showSavedElementEditDialogue(
            //       context,
            //       mainDataName: "Set Id",
            //       isNumeric: true,
            //     ).then((value) {
            //       if (value != null) {
            //         data.$.addAndSaveSet(
            //           SavedSetData(
            //             id: int.parse(value.mainData),
            //             title: value.title,
            //           ),
            //         );
            //       }
            //     });
            //   },
            // ),
          ],
        ),
      ),
      body: SafeArea(
        child: !data.isAssigned
            ? const CircularProgressIndicator()
            : _buildSingleLevelView(),
      ),
    );
  }

  ListView _buildSingleLevelView() {
    return ListView.builder(
      itemCount: data.$.length,
      itemBuilder: (context, index) {
        if (index >= 0 && data.$.length > index) {
          return _buildSavedEntry(
            entry: data.$[index],
            context: context,
          );
        } else {
          return null;
        }
      },
    );
  }

  Future<({String mainData, String title, String? parent, String? uniqueId})?>
      showSavedElementEditDialogue(
    BuildContext context, {
    String initialTitle = "",
    String initialData = "",
    String mainDataName = "Tags",
    String initialParent = "",
    String initialUniqueId = "",
    bool isNumeric = false,
  }) {
    return showDialog<
        ({String mainData, String title, String? parent, String? uniqueId})>(
      context: context,
      builder: (context) {
        var title = initialTitle,
            mainData = initialData,
            parent = initialParent,
            uniqueId = initialUniqueId;
        return AlertDialog(
          content: Column(
            children: [
              const Text("Title:"),
              TextField(
                onChanged: (value) => title = value,
                controller: util.defaultSelection(initialTitle),
              ),
              Text("$mainDataName:"),
              TextField(
                // onChanged: (value) =>
                //  mainData = isNumeric && int.tryParse(value) != null
                //    ? value
                //    : mainData,
                inputFormatters: isNumeric ? [util.numericFormatter] : null,
                onChanged: (value) => mainData = value,
                controller: util.defaultSelection(initialData),
                keyboardType: isNumeric ? TextInputType.number : null,
              ),
              const Text("Parent:"),
              TextField(
                onChanged: (value) => parent = value,
                controller: util.defaultSelection(initialParent),
              ),
              const Text("UniqueId:"),
              TextField(
                onChanged: (value) => uniqueId = value,
                controller: util.defaultSelection(initialUniqueId),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                (
                  title: title,
                  mainData: mainData,
                  parent: parent,
                  uniqueId: uniqueId
                ),
              ),
              child: const Text("Accept"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  ListTile _buildSavedEntry<T extends SavedEntry>({
    required BuildContext context,
    required T entry,
  }) {
    // var ret = () => Navigator.pop<String>(
    //       context,
    //       entry.searchString,
    //     );
    return ListTile(
      leading: switch (entry.runtimeType) {
        SavedSearchData => const Text("S"),
        SavedPoolData => const Text("P"),
        SavedSetData => const Text("s"),
        _ => throw UnsupportedError("not supported"),
      },
      title: Text(entry.title),
      subtitle: Text(entry.searchString),
      onTap: () {
        showDialog<String>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(entry.title),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Search",
                        ),
                    child: const Text("Search")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Edit",
                        ),
                    child: const Text("Edit")),
              ],
            );
          },
        ).then((v) => switch (v) {
              "Search" => Navigator.pop<String>(
                  context,
                  entry.searchString,
                ),
              "Edit" => showSavedElementEditDialogue(context,
                        initialTitle: entry.title,
                        initialData: entry.searchString,
                        initialParent: entry.parent,
                        initialUniqueId: entry.uniqueId,
                        mainDataName: "Data")
                    .then((value) {
                  if (value != null) {
                    data.$.editAndSave(
                      edited: switch (entry.runtimeType) {
                        SavedPoolData => SavedPoolData.fromSearchString(
                            // id: int.parse(value.mainData),
                            searchString: value.mainData,
                            title: value.title,
                          ),
                        SavedSetData => SavedSetData.fromSearchString(
                            // id: int.parse(value.mainData),
                            searchString: value.mainData,
                            title: value.title,
                          ),
                        SavedSearchData => SavedSearchData.fromSearchString(
                            searchString: value.mainData,
                            title: value.title,
                            parent: value.parent ?? "",
                            uniqueId: value.uniqueId ?? "",
                          ),
                        _ => throw UnsupportedError("type not supported"),
                      },
                      original: entry,
                    );
                  }
                }),
              null => null,
              _ => throw UnsupportedError("type not supported"),
            });
      },
    );
  }
}

// class ExpansionPanelListExample extends StatefulWidget {
//   final List<List<SavedEntry>> data;
//   const ExpansionPanelListExample({super.key, required this.data});

//   @override
//   State<ExpansionPanelListExample> createState() =>
//       _ExpansionPanelListExampleState();
// }

// class _ExpansionPanelListExampleState extends State<ExpansionPanelListExample> {
//   final List<Item> _data = generateItems(8);

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       child: Container(
//         child: _buildPanel(),
//       ),
//     );
//   }

//   Widget _buildPanel() {
//     return ExpansionPanelList(
//       expansionCallback: (int index, bool isExpanded) {
//         setState(() {
//           _data[index].isExpanded = isExpanded;
//         });
//       },
//       children: _data.map<ExpansionPanel>((Item item) {
//         return ExpansionPanel(
//           headerBuilder: (BuildContext context, bool isExpanded) {
//             return ListTile(
//               title: Text(item.headerValue),
//             );
//           },
//           body: ListTile(
//               title: Text(item.expandedValue),
//               subtitle:
//                   const Text('To delete this panel, tap the trash can icon'),
//               trailing: const Icon(Icons.delete),
//               onTap: () {
//                 setState(() {
//                   _data.removeWhere((Item currentItem) => item == currentItem);
//                 });
//               }),
//           isExpanded: item.isExpanded,
//         );
//       }).toList(),
//     );
//   }
// }
