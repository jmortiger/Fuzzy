import 'package:e621/e621.dart' as e621;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/saved_data.dart';
import 'package:fuzzy/widget_lib.dart' as w;
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/widgets/w_update_set.dart';

class SearchSetRoute with IRoute<WSearchSet> {
  const SearchSetRoute();
  static const $ = SearchSetRoute();
  // #region Routing
  static const routeNameConst = "/post_sets",
      routeSegmentsConst = ["post_sets"],
      routePathConst = "/post_sets",
      hasStaticPathConst = true,
      queryMappingConst = {
        "initialLimit": "limit",
        "limit": "initialLimit",
        "initialSearchCreatorId": "search[creator_id]",
        "search[creator_id]": "initialSearchCreatorId",
        "initialPage": "page",
        "page": "initialPage",
        "initialSearchName": "search[name]",
        "search[name]": "initialSearchName",
        "initialSearchIds": "search[id]",
        "search[id]": "initialSearchIds",
        "initialSearchShortname": "search[shortname]",
        "search[shortname]": "initialSearchShortname",
        "initialSearchCreatorName": "search[creator_name]",
        "search[creator_name]": "initialSearchCreatorName",
        "initialSearchOrder": "search[order]",
        "search[order]": "initialSearchOrder",
        "initialMaintainerId": "maintainer_id",
        "maintainer_id": "initialMaintainerId",
      };
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;

  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final (:url, :parameters, :id) = IRoute.legacyRouteInit(settings);
    if (url.path != routePathConst) {
      final s = "Routing failure: non-matching path\n"
          "\tExpected: $routePathConst\n"
          "\tActual: ${url.path}\n"
          "\tRoute: ${settings.name}\n"
          "\tId: $id\n"
          "\tArgs: ${settings.arguments}";
      IRoute.routeLogger.severe(s);
      throw StateError(s);
    }
    final r = RouteParameterResolver.fromRouteSettings(
      settings,
      routeSegmentsConst,
      hasStaticPath: hasStaticPathConst,
    );
    return WSearchSet(
      onSelected: null,
      initialLimit: int.tryParse(r["limit"] ?? ""),
      initialSearchCreatorId: int.tryParse(r["search[creator_id]"] ?? ""),
      initialPage: r["page"],
      initialSearchName: r["search[name]"],
      initialSearchIds:
          r.parameters["search[id]"]?.map((e) => int.parse(e)).toList(),
      initialSearchShortname: r["search[shortname]"],
      initialSearchCreatorName: r["search[creator_name]"],
      initialSearchOrder: r["search[order]"] != null
          ? e621.SetOrder(r["search[order]"]!)
          : null,
      initialMaintainerId:
          r["maintainer_id"] != null ? int.tryParse(r["maintainer_id"]!) : null,
      isFullPage: true,
    );
  }
  // #endregion Routing
}

class WSearchSet extends StatefulWidget {
  final String? initialSearchName;
  final List<int>? initialSearchIds;
  final String? initialSearchShortname;
  final String? initialSearchCreatorName;
  final int? initialSearchCreatorId;
  final int? initialMaintainerId;
  final e621.SetOrder? initialSearchOrder;
  final int? initialLimit;
  final String? initialPage;

  /// Search options initially expanded.
  final bool initiallyExpandSearchOptions;
  final bool hasInitialSearch;
  final int? limit;
  final bool showCreateSetButton;
  final bool returnOnCreateSet;
  final bool popOnSelect;
  final bool showEditableSets;
  bool get allowMultiSelect => (onMultiselectCompleted ?? onDeselected) != null;
  final bool isFullPage;

  /// Can pop
  final void Function(e621.PostSet set)? onSelected;

  /// If not null, will enable multiselect
  final void Function(e621.PostSet set)? onDeselected;

  /// If not null, will enable multiselect
  ///
  /// If [isFullPage], this will be called before automatically popping.
  final void Function(List<e621.PostSet> set)? onMultiselectCompleted;
  // final bool Function(e621.PostSet set)? disableResults;
  final bool Function(e621.PostSet set)? filterResults;
  final Future<bool> Function(e621.PostSet set)? filterResultsAsync;
  final Future<List<e621.PostSet>> Function(List<e621.PostSet> set)?
      customFilterResultsAsync;
  const WSearchSet({
    super.key,
    required this.onSelected,
    this.onDeselected,
    this.onMultiselectCompleted,
    this.initialSearchName,
    this.initialSearchIds,
    this.initialSearchShortname,
    this.initialSearchCreatorName,
    this.initialSearchCreatorId,
    this.initialSearchOrder,
    this.initialMaintainerId,
    this.initialLimit,
    this.initialPage,
    this.initiallyExpandSearchOptions = false,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
    this.showCreateSetButton = false,
    this.returnOnCreateSet = true,
    this.popOnSelect = true,
    this.isFullPage = false,
  })  : hasInitialSearch = true,
        showEditableSets = false;
  const WSearchSet.noInitialSearch({
    super.key,
    required this.onSelected,
    this.onDeselected,
    this.onMultiselectCompleted,
    this.initiallyExpandSearchOptions = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
    this.showCreateSetButton = false,
    this.returnOnCreateSet = true,
    this.popOnSelect = true,
    this.isFullPage = false,
  })  : hasInitialSearch = false,
        initialSearchName = null,
        initialSearchIds = null,
        initialSearchShortname = null,
        initialSearchCreatorName = null,
        initialSearchCreatorId = null,
        initialSearchOrder = null,
        initialMaintainerId = null,
        initialLimit = null,
        initialPage = null,
        showEditableSets = false;

  /// TODO: make maintainer id an option?
  const WSearchSet.showEditableSets({
    super.key,
    required this.onSelected,
    this.onDeselected,
    this.onMultiselectCompleted,
    this.initiallyExpandSearchOptions = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
    this.showCreateSetButton = true,
    this.returnOnCreateSet = true,
    this.popOnSelect = true,
    this.isFullPage = false,
  })  : hasInitialSearch = true,
        initialSearchName = null,
        initialSearchIds = null,
        initialSearchShortname = null,
        initialSearchCreatorName = null,
        initialSearchCreatorId = null,
        initialSearchOrder = null,
        initialMaintainerId = null,
        initialLimit = null,
        initialPage = null,
        showEditableSets = true;

  @override
  State<WSearchSet> createState() => _WSearchSetState();

  // static Future<List<e621.PostSet>> filterHasMaintenancePrivileges(List<e621.PostSet> set) {

  // }
}

class _WSearchSetState extends State<WSearchSet> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WSearchSet").logger;
  late SetSearchParameterModel p;
  String? get searchName => p.searchName;
  set searchName(String? value) => p.searchName = value;
  List<int>? get searchIds => p.searchIds;
  set searchIds(List<int>? value) => p.searchIds = value;
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
  List<e621.PostSet> selected = [];
  void clearSets() {
    sets = null;
    selected.clear();
  }

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
      searchIds: widget.initialSearchIds,
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
      clearSets();
      loadingSets = (!showEditableSets
              ? e621
                  .sendRequest(e621.initSetSearch(
                    searchName: searchName,
                    searchIds: searchIds,
                    searchShortname: searchShortname,
                    searchCreatorName: searchCreatorName,
                    searchCreatorId: searchCreatorId,
                    searchOrder: searchOrder,
                    maintainerId: p.maintainerId,
                    limit: limit,
                    page: page,
                    credentials: E621AccessData.forcedUserDataSafe?.cred,
                  ))
                  .then((value) => value.body)
              : e621
                  .sendRequest(e621.initSetGetModifiable(
                    credentials: E621AccessData.forcedUserDataSafe?.cred,
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
                          credentials: E621AccessData.forcedUserDataSafe?.cred,
                        ))
                        .then((value) => value.body),
                  ))
          .then((t) async {
        Iterable<e621.PostSet> v;
        try {
          v = e621.PostSet.fromRawJsonResults(t);
        } catch (e, s) {
          logger.warning("Failed to parse results", e, s);
          v = <e621.PostSet>[];
        }
        if (widget.filterResultsAsync == null) return v;
        try {
          // var b =
          //     await Future.wait(v.map((e) => widget.filterResultsAsync!(e)));
          // return v.where((e) => b.removeAt(0));
          final r = <e621.PostSet>[];
          for (final e in v) {
            if (await widget.filterResultsAsync!(e)) r.add(e);
          }
          return r;
        } catch (e, s) {
          logger.warning("Failed to filter results asynchronously", e, s);
          return v;
        }
      }).then((v) {
        if (mounted) {
          setState(() {
            sets = (widget.filterResults == null
                    ? v
                    : v.where(widget.filterResults!))
                .toList();
            loadingSets = null;
          });
          return sets!;
        } else {
          return v.toList();
        }
      });
      if (collapse) _control.collapse();
    });
  }

  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
          title: !showEditableSets
              ? const Text("Sets")
              : const Text("Owned/Maintained Sets"),
          leading: widget.allowMultiSelect
              ? BackButton(onPressed: () {
                  widget.onMultiselectCompleted?.call(selected);
                  if (widget.isFullPage) Navigator.pop(this.context, selected);
                })
              : null,
        ),
        root = [
          if (!widget.isFullPage) appBar,
          Expanded(
            child: ListView(
              children: [
                if (!showEditableSets)
                  ExpansionTile(
                    title: const Text("Search Options"),
                    controller: _control,
                    dense: true,
                    initiallyExpanded: widget.initiallyExpandSearchOptions,
                    children: [
                      ListTile(
                        title: TextField(
                          maxLines: 1,
                          onChanged: (v) => searchIds = v
                              .replaceAll(RegExp("[^0-9]+"), " ")
                              .trim()
                              .split(" ")
                              .map((e) => int.parse(e))
                              .toList(),
                          decoration: const InputDecoration.collapsed(
                              hintText: "Set Ids (comma separated list)"),
                          controller: searchIds != null
                              ? TextEditingController(
                                  text: searchIds!.join(", "))
                              : null,
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => TextEditingValue(
                                text: newValue.text
                                    .replaceAll(RegExp("[^0-9, ]+"), ""),
                                selection: TextSelection.collapsed(
                                    offset: newValue.selection.start),
                              ),
                            )
                          ],
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
                      w.WIntegerField(
                        name: "Set Creator Id",
                        getVal: () => searchCreatorId ?? -1,
                        setVal: (v) => searchCreatorId = v,
                        validateVal: (p1) => p1 != null && p1 >= 0,
                      ),
                      w.WEnumField(
                        name: "Order",
                        getVal: () => searchOrder ?? e621.SetOrder.updatedAt,
                        setVal: (Enum v) => searchOrder = v as e621.SetOrder,
                        values: e621.SetOrder.values,
                      ),
                      w.WIntegerField(
                        name: "Limit",
                        getVal: () => limit ?? 50,
                        setVal: (v) => limit = v,
                        validateVal: (p1) => p1 != null && p1 > 0 && p1 <= 320,
                      ),
                      w.WIntegerField(
                        name: "Page Number",
                        getVal: () => p.pageNumber ?? 1,
                        setVal: (v) => p.pageNumber = v,
                        validateVal: (p1) => p1 != null && p1 > 0,
                      ),
                      TextButton(
                        onPressed: launchSearch,
                        child: const Text("Search"),
                      ),
                    ],
                  ),
                if (sets?.firstOrNull != null)
                  ...sets!.map(widget.allowMultiSelect
                      ? (e) => WSetTile.allowMultiSelect(
                            set: e,
                            onSelected: (set) {
                              setState(() => selected.add(set));
                              widget.onSelected?.call(set);
                            },
                            onDeselected: (set) {
                              setState(() => selected.remove(set));
                              widget.onDeselected?.call(set);
                            },
                            isSelected: selected.any((s) => s.id == e.id),
                          )
                      : (e) => WSetTile(
                            set: e,
                            onSelected: widget.onSelected ??
                                (e621.PostSet set) =>
                                    Navigator.pop(context, set),
                          )),
                if (loadingSets != null) util.spinnerFitted,
                // const AspectRatio(
                //   aspectRatio: 1,
                //   child: CircularProgressIndicator(),
                // ),
              ],
            ),
          ),
          if (sets != null)
            if (sets!.isEmpty)
              const Text("No Results")
            else
              Text("${sets!.length} Results"),
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
        ];
    return widget.isFullPage
        ? Scaffold(
            appBar: appBar,
            body: Column(children: root),
          )
        : SizedBox(
            width: double.maxFinite,
            height: double.maxFinite,
            child: Column(
                children: root), //ExpansionTile(title: appBar, children: root),
          );
  }
}

/// TODO: Improve multiselect experience
class WSetTile extends StatelessWidget {
  const WSetTile({
    super.key,
    required this.set,
    required this.onSelected,
  })  : allowMultiSelect = false,
        isSelected = false,
        onDeselected = null;
  const WSetTile.allowMultiSelect({
    super.key,
    required this.set,
    required this.onSelected,
    required void Function(e621.PostSet set) this.onDeselected,
    required this.isSelected,
  }) : allowMultiSelect = true;

  final e621.PostSet set;

  final void Function(e621.PostSet set) onSelected;
  final void Function(e621.PostSet set)? onDeselected;

  final bool allowMultiSelect;
  final bool isSelected;

  void Function() get onTap =>
      !isSelected ? () => onSelected(set) : () => onDeselected?.call(set);
  @override
  Widget build(BuildContext context) {
    void showDetailDialog() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(set.name),
                ListTile(
                  title: isSelected
                      ? const Text("Deselect")
                      : const Text("Select"),
                  onTap: onTap,
                ),
                ListTile(
                  title: const Text("Search by shortname"),
                  // onTap: () => Navigator.push(
                  //     ctx,
                  //     MaterialPageRoute(
                  //       builder: (context) => buildHomePageWithProviders(
                  //         searchText: set.searchByShortname,
                  //       ),
                  //     )),
                  onTap: () => Navigator.pushNamed(
                      ctx,
                      Uri(
                        path: "/posts",
                        queryParameters: {"tags": set.searchByShortname},
                      ).toString()),
                ),
                ListTile(
                  title: const Text("Search by id"),
                  // onTap: () => Navigator.push(
                  //     ctx,
                  //     MaterialPageRoute(
                  //       builder: (context) => buildHomePageWithProviders(
                  //         searchText: set.searchById,
                  //       ),
                  //     )),
                  onTap: () => Navigator.pushNamed(
                      ctx,
                      Uri(
                        path: "/posts",
                        queryParameters: {"tags": set.searchById},
                      ).toString()),
                ),
                // TODO: Check if editable first, something like WarnPage?
                ListTile(
                  title: const Text("Edit Set"),
                  onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text("Editing ${set.id} (${set.name})"),
                          ),
                          body: WUpdateSet(set: set),
                        ),
                      )),
                ),
                if (!((AppSettings.i?.blacklistedTags
                            .contains(set.searchByShortname) ??
                        true) ||
                    AppSettings.i!.blacklistedTags.contains(set.searchById)))
                  ListTile(
                    title: const Text("Add to local blacklist"),
                    onTap: () {
                      AppSettings.i?.blacklistedTags.add(
                          SearchView.i.preferSetShortname
                              ? set.searchByShortname
                              : set.searchById);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(ctx);
                    },
                  ),
                if (AppSettings.i?.blacklistedTags.contains(set.searchById) ??
                    false)
                  ListTile(
                    title: const Text("Remove from local blacklist"),
                    onTap: () {
                      AppSettings.i?.blacklistedTags.remove(set.searchById);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(ctx);
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
                      Navigator.pop(ctx);
                    },
                  ),
                if (!((AppSettings.i?.favoriteTags
                            .contains(set.searchByShortname) ??
                        true) ||
                    AppSettings.i!.favoriteTags.contains(set.searchById)))
                  ListTile(
                    title: const Text("Add to local favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.add(
                          SearchView.i.preferSetShortname
                              ? set.searchByShortname
                              : set.searchById);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(ctx);
                    },
                  ),
                if (AppSettings.i?.favoriteTags.contains(set.searchById) ??
                    false)
                  ListTile(
                    title: const Text("Remove from local favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.remove(set.searchById);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(ctx);
                    },
                  ),
                if (AppSettings.i?.favoriteTags
                        .contains(set.searchByShortname) ??
                    false)
                  ListTile(
                    title: const Text("Remove from favorites"),
                    onTap: () {
                      AppSettings.i?.favoriteTags.remove(set.searchByShortname);
                      AppSettings.i?.writeToFile();
                      Navigator.pop(ctx);
                    },
                  ),
                if (!SavedDataE6.all.any((e) =>
                    e.searchString == set.searchById ||
                    e.searchString == set.searchByShortname))
                  ListTile(
                    title: const Text("Add to saved searches"),
                    onTap: () {
                      Navigator.pop(ctx);
                      showSavedElementEditDialogue(
                        ctx,
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
                if (SavedDataE6.isInit && SavedDataE6.searches.isNotEmpty)
                  ListTile(
                    title: const Text("Add tag to a saved search"),
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog<SavedSearchData>(
                        context: ctx,
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
                              ctx,
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
                                  edited: SavedSearchData.fromTagsString(
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
                    Clipboard.setData(ClipboardData(text: text)).then((v) {
                      util.showUserMessage(
                          // ignore: use_build_context_synchronously
                          context: ctx,
                          content: Text("$text added to clipboard."));
                      // ignore: use_build_context_synchronously
                      Navigator.pop(ctx);
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            )
          ],
        ),
      );
    }

    final detailButton = IconButton(
      onPressed: showDetailDialog,
      icon: const Icon(Icons.question_mark),
    );
    return ListTile(
      title: Text("${set.id}: ${set.name} (${set.searchByShortname})"),
      subtitle: Text.rich(TextSpan(
          text: "Posts: ${set.postCount}, "
              "Last Updated: ${set.updatedAt}, "
              "Created at ${set.createdAt} by ",
          children: [WidgetSpan(child: w.UserIdentifier(id: set.creatorId))])),
      onTap:
          !isSelected ? () => onSelected(set) : () => onDeselected?.call(set),
      onLongPress: showDetailDialog,
      leading: allowMultiSelect
          ? Checkbox(
              value: isSelected,
              onChanged: (v) => v! ? onSelected(set) : onDeselected?.call(set))
          : detailButton,
      trailing: allowMultiSelect ? detailButton : null,
    );
  }
}

class SetSearchParameterModel with PageSearchParameterNullable {
  SetSearchParameterModel({
    this.searchName,
    this.searchIds,
    this.searchShortname,
    this.searchCreatorName,
    this.searchCreatorId,
    this.searchOrder,
    this.limit,
    this.page,
  });

  String? searchName;
  List<int>? searchIds;

  String? searchShortname;

  String? searchCreatorName;

  int? searchCreatorId;
  int? maintainerId;

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
    List<int>? searchIds,
    String? searchShortname,
    String? searchCreatorName,
    int? searchCreatorId,
    e621.SetOrder? searchOrder,
    int? limit,
    String? page,
  })  : _searchName = searchName,
        _searchIds = searchIds,
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

  List<int>? _searchIds;
  @override
  List<int>? get searchIds => _searchIds;
  @override
  set searchIds(List<int>? value) {
    _searchIds = value;
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

  int? _maintainerId;
  @override
  int? get maintainerId => _maintainerId;
  @override
  set maintainerId(int? value) {
    _maintainerId = value;
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

Future<String> modifiableSetsJsonToSetsJson(String value) => Future.wait(
      e621.ModifiablePostSets.fromRawJson(value).all.map(
            (e) =>
                e621.sendRequest(e621.initSetGet(e.id)).then((e1) => e1.body),
          ),
    ).then(
      (value) => "[${value.fold(
            "",
            (p, e) => "$p, $e",
          ).substring(2)}]",
    );
