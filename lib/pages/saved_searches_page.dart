import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/tws_interop.dart' as tws;
import 'package:fuzzy/web/e621/e621.dart' as mye6;
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:provider/provider.dart';
import 'package:fuzzy/log_management.dart' as lm;

class SavedSearchesPageProvider extends StatelessWidget {
  const SavedSearchesPageProvider({super.key});

  @override
  Widget build(BuildContext context) {
    var t = SavedDataE6.loadOrRecycle();
    return (t is SavedDataE6)
        ? ChangeNotifierProvider(
            create: (context) => SavedDataE6.recycle(),
            builder: (context, child) => Consumer<SavedDataE6>(
              builder: (context, value, child) => SavedSearchesPageSingleton(
                data: value,
              ),
            ),
          )
        : FutureBuilder(
            future: t,
            builder: (context, snapshot) => snapshot.hasData
                ? ChangeNotifierProvider(
                    create: (context) => SavedDataE6.recycle(),
                    builder: (context, child) => Consumer<SavedDataE6>(
                          builder: (context, value, child) =>
                              SavedSearchesPageSingleton(
                            data: value,
                          ),
                        ))
                : util.fullPageSpinner);
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
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("SavedSearchesPage").logger;
  var data = LateInstance<SavedDataE6>();
  var parentedCollection =
      LateInstance<ListNotifier<ListNotifier<SavedEntry>>>();
  // var selected = <({int parentIndex, int childIndex, SavedEntry entry})>{};
  var selected = SetNotifier<SavedEntry>();
  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      data.$ = widget.data!;
      parentedCollection.$ = widget.data!.$parented;
    } else {
      switch (SavedDataE6.loadOrRecycle()) {
        case Future<SavedDataE6> t:
          logger.finer("async");
          t.then(
            (v) {
              setState(() {
                data.$ = v;
                parentedCollection.$ = v.$parented;
              });
            },
          ).onError(util.defaultOnError);
          break;
        case SavedDataE6 t:
          logger.finer("sync");
          data.$ = t;
          parentedCollection.$ = t.$parented;
          break;
      }
    }
  }

  void _addSearchDirect(SavedElementRecord value) {
    data.$ /* SavedDataE6 */ .addAndSaveSearch(
      SavedSearchData.fromTagsString(
        searchString: value.mainData,
        title: value.title,
        uniqueId: value.uniqueId ?? "",
        parent: value.parent ?? "",
      ),
    );
    setState(() {
      parentedCollection.$ = data.$.$parented;
    });
  }

  void _addSearch() => showSavedElementEditDialogue(
        context,
      ).then((value) {
        if (value != null) {
          _addSearchDirect(value);
        }
      });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Searches"),
        actions: [
          IconButton(
            onPressed: _addSearch,
            icon: const Icon(Icons.add),
            tooltip: "Add Saved Search",
          ),
          TextButton.icon(
            onPressed: data.$Safe?.$searches.clear,
            icon: const Icon(Icons.clear),
            label: const Text("Clear Saved Searches"),
          ),
          TextButton.icon(
            onPressed: () {
              tws.showEnhancedImportElementEditDialogue(context).then((v) {
                if (v != null) {
                  // for (var e in v) {
                  //   _addSearchDirect(e.toSer());
                  // }
                  for (var e in v) {
                    _addSearchDirect(e);
                  }
                }
              });
            },
            icon: const Icon(Icons.import_export),
            label: const Text("Import Saved Searches from The Wolf's Stash"),
          ),
        ],
      ),
      // endDrawer: _buildDrawer(),
      body: SafeArea(
        child: !data.isAssigned
            ? const CircularProgressIndicator()
            : _buildParentedView(),
        // : _buildSingleLevelView(),
      ),
      floatingActionButton: StatefulBuilder(
        builder: (context, setState) {
          void l() {
            selected.removeListener(l);
            setState(() {});
          }

          selected.addListener(l);
          return ExpandableFab(
            openIcon: Text(selected.length.toString()),
            children: selected.isNotEmpty
                ? [
                    ActionButton(
                      icon: true //!Platform.isDesktop && !util.isDebug
                          ? const Icon(Icons.delete)
                          : TextButton.icon(
                              onPressed: _deleteSelected,
                              icon: const Icon(Icons.delete),
                              label: const Text("Delete"),
                            ),
                      tooltip: "Delete",
                      onPressed: _deleteSelected,
                    ),
                    ActionButton(
                      icon: true //!Platform.isDesktop && !util.isDebug
                          ? const Icon(Icons.edit)
                          : TextButton.icon(
                              onPressed: _changeParentsOfSelected,
                              icon: const Icon(Icons.edit),
                              label: const Text("Change Parent"),
                            ),
                      tooltip: "Change Parent",
                      onPressed: _changeParentsOfSelected,
                    ),
                  ]
                : [],
          );
        },
      ),
    );
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text("Are you sure you want to delete ${selected.length} entries?"),
        content: Text(selected.fold(
          "Entries include: ",
          (previousValue, element) => "$previousValue\n${element.searchString}",
        )),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text("Confirm"),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.cancel),
            label: const Text("Confirm"),
          ),
        ],
      ),
    ).then(
      (value) {
        if (value ?? false) {
          data.$.removeEntries(selected);
          setState(() {
            selected.clear();
          });
          setState(() {
            parentedCollection.$ = data.$.$parented;
          });
        }
      },
    );
  }

  void _changeParentsOfSelected() {
    showDialog<String>(
      context: context,
      builder: (context) {
        String newParent = "";
        return AlertDialog(
          title: const Text("Change Parent Names"),
          content: SizedBox(
            height: double.maxFinite,
            width: double.maxFinite,
            child: buildParentSuggestionsEntry(
              context,
              // initialParent: selected.fold(<({int count, String parent})>[], ),
              onChanged: (p) => newParent = p,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, newParent),
              icon: const Icon(Icons.check),
              label: const Text("Confirm"),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.cancel),
              label: const Text("Confirm"),
            ),
          ],
        );
      },
    ).then(
      (value) {
        if (value != null) {
          setState(() {
            for (var e in selected) {
              data.$.editAndSave(
                original: e,
                edited: e.copyWith(parent: value),
              );
            }
          });
          setState(() {
            parentedCollection.$ = data.$.$parented;
          });
          // data.$.removeEntries(selected.map((e) => e.entry));
          setState(() {
            selected.clear();
          });
        }
      },
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text("TGH"),
          ),
          ListTile(
            title: const Text("Add Saved Search"),
            onTap: _addSearch,
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
    );
  }

  ListView _buildSingleLevelView() {
    return ListView.builder(
      itemCount: data.$.$searches.length,
      itemBuilder: (context, index) {
        return index >= 0 && data.$.$searches.length > index
            ? _buildSavedEntry(entry: data.$.$searches[index])
            : null;
      },
    );
  }

  Widget _buildParentedView() {
    return ListView(
      children: parentedCollection.$.mapAsList(
        (e, index, list) => ExpansionTile(
          key: PageStorageKey(e),
          maintainState: true,
          title: Text.rich(
            TextSpan(
              text: e.first.parent,
              children: [
                TextSpan(
                    text: " (${e.length} entries)",
                    style: const DefaultTextStyle.fallback().style.copyWith(
                          color: const Color.fromARGB(255, 80, 80, 80),
                        )),
              ],
            ),
          ),
          dense: true,
          children: e.mapAsList(
            (e2, i2, l2) => _buildSavedEntry(
              entry: e2,
              index: (parentIndex: index, childIndex: i2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedEntry<T extends SavedEntry>({
    required T entry,
    ({int parentIndex, int childIndex})? index,
  }) {
    final r = index != null ? entry : null;
    return StatefulBuilder(
      builder: (context, setState) {
        void l() {
          selected.removeListener(l);
          setState(() {});
        }

        selected.addListener(l);
        return ListTile(
          // leading: switch (entry.runtimeType) {
          //   SavedSearchData => const Text("S"),
          //   SavedPoolData => const Text("P"),
          //   SavedSetData => const Text("s"),
          //   _ => throw UnsupportedError("not supported"),
          // },
          leading: r != null && selected.isNotEmpty
              ? Checkbox(
                  value: selected.contains(r),
                  onChanged: (value) =>
                      value! ? selected.add(r) : selected.remove(r),
                )
              : switch (entry.runtimeType) {
                  SavedSearchData => const Text("S"),
                  SavedPoolData => const Text("P"),
                  SavedSetData => const Text("s"),
                  _ => throw UnsupportedError("not supported"),
                },
          title: Text(entry.title),
          subtitle: Text(entry.searchString),
          onLongPress: r != null
              ? () =>
                  selected.contains(r) ? selected.remove(r) : selected.add(r)
              : null,
          onTap: () => showEntryDialog(context: context, entry: entry)
              .then((v) => processEntryDialogSelection(entry, v)),
        );
      },
    );
  }

  Future<SavedEntryDialogOptions?> showEntryDialog<T extends SavedEntry>({
    required BuildContext context,
    required T entry,
    List<SavedEntryDialogOptions> options = SavedEntryDialogOptions.values,
  }) =>
      showDialog<SavedEntryDialogOptions>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(entry.title),
            content: Text(
              "Parent: ${entry.parent}\n"
              "Search String: ${entry.searchString}\n"
              "Unique Id: ${entry.uniqueId}\n",
            ),
            actions: options.map((e) => e.buttonWidget(context)).toList(),
          );
        },
      );

  processEntryDialogSelection<T extends SavedEntry>(
    T entry,
    SavedEntryDialogOptions? v,
  ) =>
      switch (v) {
        SavedEntryDialogOptions.search => Navigator.pop<String>(
            context,
            entry.searchString,
          ),
        SavedEntryDialogOptions.searchById => Navigator.pop<String>(
            context,
            "${mye6.E621.delimiter}${entry.uniqueId}",
          ),
        SavedEntryDialogOptions.addToClipboard =>
          Clipboard.setData(ClipboardData(text: entry.searchString)).then((v) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text("${entry.searchString} added to clipboard."),
              ));
            Navigator.pop(context);
          }),
        SavedEntryDialogOptions.addIdToClipboard =>
          Clipboard.setData(ClipboardData(
            text: "${mye6.E621.delimiter}${entry.uniqueId}",
          )).then((v) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                  content: Text(
                "${mye6.E621.delimiter}${entry.uniqueId} added to clipboard.",
              )));
            Navigator.pop(context);
          }),
        SavedEntryDialogOptions.delete =>
          data.$ /* SavedDataE6 */ .removeEntry(entry),
        SavedEntryDialogOptions.edit => showSavedElementEditDialogue(context,
                  initialTitle: entry.title,
                  initialData: entry.searchString,
                  initialParent: entry.parent,
                  initialUniqueId: entry.uniqueId,
                  mainDataName: "Data",
                  initialEntry: entry)
              .then((value) {
            if (value != null) {
              data.$. /* SavedDataE6. */ editAndSave(
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
                      parent: value.parent ?? "",
                      uniqueId: value.uniqueId ?? "",
                    ),
                  // SavedSetData => SavedSetData.fromSearchString(
                  //     // id: int.parse(value.mainData),
                  //     searchString: value.mainData,
                  //     title: value.title,
                  //   ),
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
      };
}

enum SavedEntryDialogOptions {
  search,
  searchById,
  addToClipboard,
  addIdToClipboard,
  delete,
  edit;

  String get displayName => switch (this) {
        search => "Search",
        searchById => "Search w/ Unique id",
        addToClipboard => "Add to clipboard",
        addIdToClipboard => "Add Unique Id to clipboard",
        delete => "Delete",
        edit => "Edit",
      };
  Text get displayNameWidget => switch (this) {
        search => const Text("Search"),
        searchById => const Text("Search w/ Unique id"),
        addToClipboard => const Text("Add to clipboard"),
        addIdToClipboard => const Text("Add Unique Id to clipboard"),
        delete => const Text("Delete"),
        edit => const Text("Edit"),
      };
  TextButton buttonWidget(BuildContext context) => switch (this) {
        search => TextButton(
            onPressed: () => Navigator.pop(
                  context,
                  SavedEntryDialogOptions.search,
                ),
            child: SavedEntryDialogOptions.search.displayNameWidget),
        searchById => TextButton(
            onPressed: () => Navigator.pop<SavedEntryDialogOptions>(
                  context,
                  SavedEntryDialogOptions.searchById,
                ),
            child: SavedEntryDialogOptions.searchById.displayNameWidget),
        addToClipboard => TextButton(
            onPressed: () => Navigator.pop<SavedEntryDialogOptions>(
                  context,
                  SavedEntryDialogOptions.addToClipboard,
                ),
            child: SavedEntryDialogOptions.addToClipboard.displayNameWidget),
        addIdToClipboard => TextButton(
            onPressed: () => Navigator.pop<SavedEntryDialogOptions>(
                  context,
                  SavedEntryDialogOptions.addIdToClipboard,
                ),
            child: SavedEntryDialogOptions.addIdToClipboard.displayNameWidget),
        edit => TextButton(
            onPressed: () => Navigator.pop<SavedEntryDialogOptions>(
                  context,
                  SavedEntryDialogOptions.edit,
                ),
            child: SavedEntryDialogOptions.edit.displayNameWidget),
        delete => TextButton(
            onPressed: () => Navigator.pop<SavedEntryDialogOptions>(
                  context,
                  SavedEntryDialogOptions.delete,
                ),
            child: SavedEntryDialogOptions.delete.displayNameWidget),
      };
}
