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
                : util.scSaCoExArCpi);
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
  // #region Logger
  static late final lRecord = lm.genLogger("SavedSearchesPage");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  var data = LateInstance<SavedDataE6>();
  @override
  void initState() {
    if (widget.data != null) {
      data.$ = widget.data!;
    } else {
      switch (SavedDataE6.loadOrRecycle()) {
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

  void _addSearchDirect(SavedElementRecord value) =>
      data.$ /* SavedDataE6 */ .addAndSaveSearch(
        SavedSearchData.fromTagsString(
          searchString: value.mainData,
          title: value.title,
          uniqueId: value.uniqueId ?? "",
          parent: value.parent ?? "",
        ),
      );
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
          IconButton(
            onPressed: data.$Safe?.$searches.clear,
            icon: const Icon(Icons.remove),
            tooltip: "Clear Saved Searches",
          ),
          IconButton(
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
            tooltip: "Import Saved Searches from The Wolf's Stash",
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
        if (index >= 0 && data.$.$searches.length > index) {
          return _buildSavedEntry(
            entry: data.$.$searches[index],
            context: context,
          );
        } else {
          return null;
        }
      },
    );
  }

  Widget _buildParentedView() {
    return ListView(
      children: data.$.$parented.mapAsList(
        (e, index, list) => ExpansionTile(
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
              context: context,
            ),
          ),
        ),
      ),
    );
  }

  ListTile _buildSavedEntry<T extends SavedEntry>({
    required BuildContext context,
    required T entry,
  }) {
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
              content: Text(
                "Parent: ${entry.parent}\n"
                "Search String: ${entry.searchString}\n"
                "Unique Id: ${entry.uniqueId}\n",
              ),
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
                          "Search w/ Unique id",
                        ),
                    child: const Text("Search w/ Unique id")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Add to clipboard",
                        ),
                    child: const Text("Add to clipboard")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Add Unique Id to clipboard",
                        ),
                    child: const Text("Add Unique Id to clipboard")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Edit",
                        ),
                    child: const Text("Edit")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Delete",
                        ),
                    child: const Text("Delete")),
              ],
            );
          },
        ).then((v) => switch (v) {
              "Search" => Navigator.pop<String>(
                  context,
                  entry.searchString,
                ),
              "Search w/ Unique id" => Navigator.pop<String>(
                  context,
                  "${mye6.E621.delimiter}${entry.uniqueId}",
                ),
              "Add to clipboard" =>
                Clipboard.setData(ClipboardData(text: entry.searchString))
                    .then((v) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("${entry.searchString} added to clipboard."),
                  ));
                  Navigator.pop(context);
                }),
              "Add Unique Id to clipboard" => Clipboard.setData(ClipboardData(
                  text: "${mye6.E621.delimiter}${entry.uniqueId}",
                )).then((v) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                    "${mye6.E621.delimiter}${entry.uniqueId} added to clipboard.",
                  )));
                  Navigator.pop(context);
                }),
              "Delete" => data.$ /* SavedDataE6 */ .removeEntry(entry),
              "Edit" => showSavedElementEditDialogue(context,
                        initialTitle: entry.title,
                        initialData: entry.searchString,
                        initialParent: entry.parent,
                        initialUniqueId: entry.uniqueId,
                        mainDataName: "Data")
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

/* class SavedSearchesPageProviderLegacy extends StatelessWidget {
  const SavedSearchesPageProviderLegacy({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SavedDataE6Legacy.$Copy,
      builder: (context, child) => Consumer<SavedDataE6Legacy>(
        builder: (context, value, child) => SavedSearchesPageSingletonLegacy(
          data: value,
        ),
      ),
    );
  }
}

class SavedSearchesPageSingletonLegacy extends StatefulWidget {
  final SavedDataE6Legacy? data;

  const SavedSearchesPageSingletonLegacy({super.key, this.data});

  @override
  State<SavedSearchesPageSingletonLegacy> createState() =>
      _SavedSearchesPageSingletonLegacyState();
}

class _SavedSearchesPageSingletonLegacyState
    extends State<SavedSearchesPageSingletonLegacy> {
  var data = LateInstance<SavedDataE6Legacy>();
  @override
  void initState() {
    if (widget.data != null) {
      data.$ = widget.data!;
    } else {
      switch (SavedDataE6Legacy.$Async) {
        case Future<SavedDataE6Legacy> t:
          print("async");
          t.then(
            (v) {
              setState(() {
                data.$ = v;
              });
            },
          ).onError(util.defaultOnError);
          break;
        case SavedDataE6Legacy t:
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
                        searchString: value.mainData,
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
            : _buildParentedView(),
        // : _buildSingleLevelView(),
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

  Widget _buildParentedView() {
    return ListView(
      children: data.$.parented.mapAsList(
        (e, index, list) => ExpansionTile(
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
              context: context,
            ),
          ),
        ),
      ),
    );
  }

  ListTile _buildSavedEntry<T extends SavedEntry>({
    required BuildContext context,
    required T entry,
  }) {
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
              content: Text(
                "Parent: ${entry.parent}\n"
                "Search String: ${entry.searchString}\n"
                "Unique Id: ${entry.uniqueId}\n",
              ),
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
                          "Search w/ Unique id",
                        ),
                    child: const Text("Search w/ Unique id")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Edit",
                        ),
                    child: const Text("Edit")),
                TextButton(
                    onPressed: () => Navigator.pop<String>(
                          context,
                          "Delete",
                        ),
                    child: const Text("Delete")),
              ],
            );
          },
        ).then((v) => switch (v) {
              "Search" => Navigator.pop<String>(
                  context,
                  entry.searchString,
                ),
              "Search w/ Unique id" => Navigator.pop<String>(
                  context,
                  "${mye6.E621.delimiter}${entry.uniqueId}",
                ),
              "Delete" => data.$.removeEntry(entry),
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
 */