import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/main.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/widgets/w_update_set.dart';
// import 'package:http/http.dart';
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

import '../web/e621/e621_access_data.dart';

class WSearchSet extends StatefulWidget {
  final String? initialSearchName;
  final String? initialSearchShortname;
  final String? initialSearchCreatorName;
  final int? initialSearchCreatorId;
  final e621.SetOrder? initialSearchOrder;
  final int? initialLimit;
  final String? initialPage;
  final bool initiallyExpanded;
  final bool hasInitialSearch;
  final int? limit;
  final bool showCreateSetButton;
  final bool returnOnCreateSet;
  final bool popOnSelect;
  final bool showEditableSets;

  final void Function(e621.PostSet set)? onSelected;
  // final bool Function(e621.PostSet set)? disableResults;
  final bool Function(e621.PostSet set)? filterResults;
  final Future<bool> Function(e621.PostSet set)? filterResultsAsync;
  final Future<List<e621.PostSet>> Function(List<e621.PostSet> set)?
      customFilterResultsAsync;
  const WSearchSet({
    super.key,
    required this.onSelected,
    this.initialSearchName,
    this.initialSearchShortname,
    this.initialSearchCreatorName,
    this.initialSearchCreatorId,
    this.initialSearchOrder,
    this.initialLimit,
    this.initialPage,
    this.initiallyExpanded = false,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
    this.showCreateSetButton = false,
    this.returnOnCreateSet = true,
    this.popOnSelect = true,
  })  : hasInitialSearch = true,
        showEditableSets = false;
  const WSearchSet.noInitialSearch({
    super.key,
    required this.onSelected,
    this.initiallyExpanded = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
    this.showCreateSetButton = false,
    this.returnOnCreateSet = true,
    this.popOnSelect = true,
  })  : hasInitialSearch = false,
        initialSearchName = null,
        initialSearchShortname = null,
        initialSearchCreatorName = null,
        initialSearchCreatorId = null,
        initialSearchOrder = null,
        initialLimit = null,
        initialPage = null,
        showEditableSets = false;
  const WSearchSet.showEditableSets({
    super.key,
    required this.onSelected,
    this.initiallyExpanded = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
    this.showCreateSetButton = true,
    this.returnOnCreateSet = true,
    this.popOnSelect = true,
  })  : hasInitialSearch = true,
        initialSearchName = null,
        initialSearchShortname = null,
        initialSearchCreatorName = null,
        initialSearchCreatorId = null,
        initialSearchOrder = null,
        initialLimit = null,
        initialPage = null,
        showEditableSets = true;

  @override
  State<WSearchSet> createState() => _WSearchSetState();

  // static Future<List<e621.PostSet>> filterHasMaintenancePrivileges(List<e621.PostSet> set) {

  // }
}

class _WSearchSetState extends State<WSearchSet> {
  late SetSearchParameterModel p;
  String? get searchName => p.searchName;
  set searchName(String? value) => p.searchName = value;
  String? get searchShortname => p.searchShortname;
  set searchShortname(String? value) => p.searchShortname = value;
  String? get searchCreatorName => p.searchCreatorName;
  set searchCreatorName(String? value) => p.searchCreatorName = value;
  int? get searchCreatorId => p.searchCreatorId;
  set searchCreatorId(int? value) => p.searchCreatorId = value;
  e621.SetOrder? get searchOrder => p.searchOrder;
  set searchOrder(e621.SetOrder? value) => p.searchOrder = value;
  int? get limit => p.limit;
  set limit(int? value) => p.limit = value;
  String? get page => p.page;
  set page(String? value) => p.page = value;

  Future<List<e621.PostSet>>? loadingSets;
  List<e621.PostSet>? sets;
  late ExpansionTileController _control;
  bool showEditableSets = false;
  @override
  void initState() {
    super.initState();
    p = SetSearchParameterModel(
      searchName: widget.initialSearchName,
      searchShortname: widget.initialSearchShortname,
      searchCreatorName: widget.initialSearchCreatorName,
      searchCreatorId: widget.initialSearchCreatorId,
      searchOrder: widget.initialSearchOrder,
      limit: widget.initialLimit,
      page: widget.initialPage,
    );
    _control = ExpansionTileController();
    showEditableSets = widget.showEditableSets;
    if (widget.hasInitialSearch) launchSearch(false);
    // if (widget.initiallyExpanded) _control.expand();
  }

  @override
  void dispose() {
    loadingSets?.ignore();
    loadingSets = null;
    super.dispose();
  }

  void launchSearch([bool collapse = true]) {
    setState(() {
      sets = null;
      loadingSets = (!showEditableSets
              ? e621
                  .sendRequest(e621.initSetSearch(
                    searchName: searchName,
                    searchShortname: searchShortname,
                    searchCreatorName: searchCreatorName,
                    searchCreatorId: searchCreatorId,
                    searchOrder: searchOrder,
                    limit: limit,
                    page: page,
                    credentials: E621AccessData.devAccessData.$.cred,
                  ))
                  .then((value) => value.body)
              : e621
                  .sendRequest(e621.initGetModifiableSetsRequest(
                    credentials: E621AccessData.devAccessData.$.cred,
                  ))
                  .then(
                    (value) => e621
                        .sendRequest(e621.initSetSearch(
                          searchIds:
                              e621.ModifiablePostSets.fromRawJson(value.body)
                                  .all
                                  .map((e) => e.id),
                          limit: limit,
                          page: page,
                          credentials: E621AccessData.devAccessData.$.cred,
                        ))
                        .then(
                          (value) => value.body,
                        ),
                    // (value) => Future.wait(
                    //   e621.ModifiablePostSets.fromRawJson(value.body).all.map(
                    //         (e) => e621
                    //             .sendRequest(e621.initSetGet(e.id))
                    //             .then((e1) => e1.body),
                    //       ),
                    // ).then(
                    //   (value) => "[${value.fold(
                    //         "",
                    //         (p, e) => "$p, $e",
                    //       ).substring(2)}]",
                    // ),
                  ))
          .then((t) async {
        // var t = await ByteStream(v.stream.asBroadcastStream()).bytesToString();
        // var t = v.body;
        var step = jsonDecode(t);
        try {
          final v = (step as List).mapAsList(
            (e, index, list) => e621.PostSet.fromJson(e),
          );
          if (widget.filterResultsAsync == null) return v;
          final r = <e621.PostSet>[];
          for (var e in v) {
            if (await widget.filterResultsAsync!(e)) r.add(e);
          }
          return r;
        } catch (e) {
          return <e621.PostSet>[];
        }
      }).then((v) {
        if (mounted) {
          setState(() {
            sets = widget.filterResults == null
                ? v
                : v.where(widget.filterResults!).toList();
            loadingSets = null;
          });
          return sets!;
        } else {
          return v;
        }
      });
      if (collapse) _control.collapse();
    });
  }

  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: double.maxFinite,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                AppBar(title: const Text("Sets")),
                if (!showEditableSets)
                  ExpansionTile(
                    title: const Text("Search Options"),
                    controller: _control,
                    dense: true,
                    initiallyExpanded: widget.initiallyExpanded,
                    children: [
                      ListTile(
                        title: TextField(
                          maxLines: 1,
                          onChanged: (v) => searchName = v,
                          decoration: const InputDecoration.collapsed(
                              hintText: "Set Name"),
                          controller: searchName != null
                              ? TextEditingController(text: searchName!)
                              : null,
                        ),
                      ),
                      ListTile(
                        title: TextField(
                          maxLines: 1,
                          onChanged: (v) => searchShortname = v,
                          decoration: const InputDecoration.collapsed(
                              hintText: "Set Short Name"),
                          controller: searchShortname != null
                              ? TextEditingController(text: searchShortname!)
                              : null,
                        ),
                      ),
                      ListTile(
                        title: TextField(
                          maxLines: 1,
                          onChanged: (v) => searchCreatorName = v,
                          decoration: const InputDecoration.collapsed(
                              hintText: "Set Creator Name"),
                          controller: searchCreatorName != null
                              ? TextEditingController(text: searchCreatorName!)
                              : null,
                        ),
                      ),
                      WIntegerField(
                        name: "Set Creator Id",
                        getVal: () => searchCreatorId ?? -1,
                        setVal: (v) => searchCreatorId = v,
                        validateVal: (p1) => p1 != null && p1 >= 0,
                      ),
                      WEnumField(
                        name: "Order",
                        getVal: () => searchOrder ?? e621.SetOrder.updatedAt,
                        setVal: (Enum v) => searchOrder = v as e621.SetOrder,
                        values: e621.SetOrder.values,
                      ),
                      WIntegerField(
                        name: "Limit",
                        getVal: () => limit ?? 50,
                        setVal: (v) => limit = v,
                        validateVal: (p1) => p1 != null && p1 > 0 && p1 <= 320,
                      ),
                      WIntegerField(
                        name: "Page Number",
                        getVal: () => p.pageNumber ?? 50,
                        setVal: (v) => p.pageNumber = v,
                        validateVal: (p1) => p1 != null && p1 > 0,
                      ),
                      TextButton(
                        onPressed: launchSearch,
                        child: const Text("Search"),
                      ),
                    ],
                  ),
                if (loadingSets != null)
                  const AspectRatio(
                    aspectRatio: 1,
                    child: CircularProgressIndicator(),
                  ),
                if (loadingSets == null && sets?.firstOrNull == null)
                  const Text("No Results"),
                if (sets?.firstOrNull != null)
                  ...sets!.map((e) {
                    return WSetTile(
                      set: e,
                      onSelected: widget.onSelected ??
                          (e621.PostSet set) => Navigator.pop(context, set),
                    );
                  }),
              ],
            ),
          ),
          if (widget.showCreateSetButton)
            TextButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (ctx) => Scaffold(
                              appBar: AppBar(title: const Text("Create Set")),
                              body: const WUpdateSet.create(),
                            ))).then((v) {
                  if (v == null) return;
                  if (widget.returnOnCreateSet) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(this.context, v as e621.PostSet);
                  }
                  if (sets != null) {
                    setState(() {
                      sets!.insert(0, v as e621.PostSet);
                    });
                  } else {
                    launchSearch();
                  }
                });
              },
              child: const Text("Add Set"),
            ),
        ],
      ),
    );
  }
}

class WSetTile extends StatelessWidget {
  const WSetTile({
    super.key,
    required this.set,
    required this.onSelected,
  });

  final e621.PostSet set;

  final void Function(e621.PostSet set) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("${set.id}: ${set.name}"),
      subtitle: Text(
          "Posts: ${set.postCount}, Last Updated: ${set.updatedAt}, Created: ${set.createdAt}, CreatorId: ${set.creatorId}"),
      onTap: () => onSelected(set),
      leading: IconButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(set.name),
                        ListTile(
                          title: const Text("Select"),
                          onTap: () => onSelected(set),
                        ),
                        ListTile(
                          title: const Text("Search"),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    buildHomePageWithProviders(
                                  searchText: set.searchByShortname,
                                ),
                              )),
                        ),
                        ListTile(
                          title: const Text("Edit Set"),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(
                                    title:
                                        Text("Editing ${set.id} (${set.name})"),
                                  ),
                                  body: WUpdateSet(set: set),
                                ),
                              )),
                        ),
                        if (!((AppSettings.i?.blacklistedTags
                                    .contains(set.searchByShortname) ??
                                true) ||
                            AppSettings.i!.blacklistedTags
                                .contains(set.searchById)))
                          ListTile(
                            title: const Text("Add to local blacklist"),
                            onTap: () {
                              AppSettings.i?.blacklistedTags.add(
                                  SearchView.i.preferSetShortname
                                      ? set.searchByShortname
                                      : set.searchById);
                              AppSettings.i?.writeToFile();
                              Navigator.pop(context);
                            },
                          ),
                        if (AppSettings.i?.blacklistedTags
                                .contains(set.searchById) ??
                            false)
                          ListTile(
                            title: const Text("Remove from local blacklist"),
                            onTap: () {
                              AppSettings.i?.blacklistedTags
                                  .remove(set.searchById);
                              AppSettings.i?.writeToFile();
                              Navigator.pop(context);
                            },
                          ),
                        if (AppSettings.i?.blacklistedTags
                                .contains(set.searchByShortname) ??
                            false)
                          ListTile(
                            title: const Text("Remove from local blacklist"),
                            onTap: () {
                              AppSettings.i?.blacklistedTags
                                  .remove(set.searchByShortname);
                              AppSettings.i?.writeToFile();
                              Navigator.pop(context);
                            },
                          ),
                        if (!((AppSettings.i?.favoriteTags
                                    .contains(set.searchByShortname) ??
                                true) ||
                            AppSettings.i!.favoriteTags
                                .contains(set.searchById)))
                          ListTile(
                            title: const Text("Add to local favorites"),
                            onTap: () {
                              AppSettings.i?.favoriteTags.add(
                                  SearchView.i.preferSetShortname
                                      ? set.searchByShortname
                                      : set.searchById);
                              AppSettings.i?.writeToFile();
                              Navigator.pop(context);
                            },
                          ),
                        if (AppSettings.i?.favoriteTags
                                .contains(set.searchById) ??
                            false)
                          ListTile(
                            title: const Text("Remove from local favorites"),
                            onTap: () {
                              AppSettings.i?.favoriteTags
                                  .remove(set.searchById);
                              AppSettings.i?.writeToFile();
                              Navigator.pop(context);
                            },
                          ),
                        if (AppSettings.i?.favoriteTags
                                .contains(set.searchByShortname) ??
                            false)
                          ListTile(
                            title: const Text("Remove from favorites"),
                            onTap: () {
                              AppSettings.i?.favoriteTags
                                  .remove(set.searchByShortname);
                              AppSettings.i?.writeToFile();
                              Navigator.pop(context);
                            },
                          ),
                        if (!SavedDataE6.all.any((e) =>
                            e.searchString == set.searchById ||
                            e.searchString == set.searchByShortname))
                          ListTile(
                            title: const Text("Add to saved searches"),
                            onTap: () {
                              Navigator.pop(context);
                              showSavedElementEditDialogue(
                                context,
                                initialData: SearchView.i.preferSetShortname
                                    ? set.searchByShortname
                                    : set.searchById,
                                initialParent: "Set",
                                initialTitle: set.shortname,
                                initialUniqueId: set.shortname,
                              ).then((value) {
                                if (value != null) {
                                  SavedDataE6.doOnInit(
                                    () => SavedDataE6.$addAndSaveSearch(
                                      SavedSearchData.fromTagsString(
                                        searchString: value.mainData,
                                        title: value.title,
                                        uniqueId: value.uniqueId ?? "",
                                        parent: value.parent ?? "",
                                      ),
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                        if (SavedDataE6.isInit &&
                            SavedDataE6.searches.isNotEmpty)
                          ListTile(
                            title: const Text("Add tag to a saved search"),
                            onTap: () {
                              Navigator.pop(context);
                              showDialog<SavedSearchData>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("Select a search"),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: SavedDataE6.buildParentedView(
                                        context: context,
                                        generateOnTap: (e) =>
                                            () => Navigator.pop(context, e),
                                      ),
                                    ),
                                  );
                                },
                              ).then((e) => e == null
                                  ? ""
                                  : showSavedElementEditDialogue(
                                      // ignore: use_build_context_synchronously
                                      context,
                                      initialData:
                                          "${e.searchString} ${SearchView.i.preferSetShortname ? set.searchByShortname : set.searchById}",
                                      initialParent: e.parent,
                                      initialTitle: e.title,
                                      initialUniqueId: e.uniqueId,
                                      initialEntry: e,
                                    ).then((value) {
                                      if (value != null) {
                                        SavedDataE6.$editAndSave(
                                          original: e,
                                          edited:
                                              SavedSearchData.fromTagsString(
                                            searchString: value.mainData,
                                            title: value.title,
                                            uniqueId: value.uniqueId ?? "",
                                            parent: value.parent ?? "",
                                          ),
                                        );
                                      }
                                    }));
                            },
                          ),
                        ListTile(
                          title: const Text("Add to clipboard"),
                          onTap: () {
                            final text = SearchView.i.preferSetShortname
                                ? set.searchByShortname
                                : set.searchById;
                            Clipboard.setData(ClipboardData(text: text))
                                .then((v) {
                              util.showUserMessage(
                                  // ignore: use_build_context_synchronously
                                  context: context,
                                  content: Text("$text added to clipboard."));
                              // ignore: use_build_context_synchronously
                              Navigator.pop(context);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    )
                  ],
                );
              },
            );
          },
          icon: const Icon(Icons.question_mark)),
    );
  }
}

class SetSearchParameterModel with PageSearchParameterNullable {
  SetSearchParameterModel({
    this.searchName,
    this.searchShortname,
    this.searchCreatorName,
    this.searchCreatorId,
    this.searchOrder,
    this.limit,
    this.page,
  });

  String? searchName;

  String? searchShortname;

  String? searchCreatorName;

  int? searchCreatorId;

  e621.SetOrder? searchOrder;

  int? limit;

  @override
  String? page;

  set pageNumber(int? value) {
    // if (isValidPage(value?.toString() ?? "1")) {
    //   page = value?.toString();
    // }
    page = value?.toString();
  }
}

class SetSearchParameterNotifier extends ChangeNotifier
    with PageSearchParameterNullable
    implements SetSearchParameterModel {
  SetSearchParameterNotifier({
    String? searchName,
    String? searchShortname,
    String? searchCreatorName,
    int? searchCreatorId,
    e621.SetOrder? searchOrder,
    int? limit,
    String? page,
  })  : _searchName = searchName,
        _searchShortname = searchShortname,
        _searchCreatorName = searchCreatorName,
        _searchCreatorId = searchCreatorId,
        _searchOrder = searchOrder,
        _limit = limit,
        _page = page;

  String? _searchName;
  @override
  String? get searchName => _searchName;
  @override
  set searchName(String? value) {
    _searchName = value;
    notifyListeners();
  }

  String? _searchShortname;
  @override
  String? get searchShortname => _searchShortname;
  @override
  set searchShortname(String? value) {
    _searchShortname = value;
    notifyListeners();
  }

  String? _searchCreatorName;
  @override
  String? get searchCreatorName => _searchCreatorName;
  @override
  set searchCreatorName(String? value) {
    _searchCreatorName = value;
    notifyListeners();
  }

  int? _searchCreatorId;
  @override
  int? get searchCreatorId => _searchCreatorId;
  @override
  set searchCreatorId(int? value) {
    _searchCreatorId = value;
    notifyListeners();
  }

  e621.SetOrder? _searchOrder;
  @override
  e621.SetOrder? get searchOrder => _searchOrder;
  @override
  set searchOrder(e621.SetOrder? value) {
    _searchOrder = value;
    notifyListeners();
  }

  int? _limit;
  @override
  int? get limit => _limit;
  @override
  set limit(int? value) {
    _limit = value;
    notifyListeners();
  }

  String? _page;
  @override
  String? get page => _page;
  @override
  set page(String? value) {
    _page = value;
    notifyListeners();
  }

  @override
  set pageNumber(int? value) {
    // if (isValidPage(value?.toString() ?? "1")) {
    //   _page = value?.toString();
    //   notifyListeners();
    // }
    _page = value?.toString();
    notifyListeners();
  }
}
