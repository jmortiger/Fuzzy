import 'package:e621/e621.dart' as e621;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/pages/settings_page.dart' as w;
import 'package:fuzzy/widget_lib.dart' as w;
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:fuzzy/log_management.dart' as lm;

import '../web/e621/e621_access_data.dart';

class WSearchPool extends StatefulWidget {
  final String? initialSearchNameMatches;
  final List<int>? initialSearchId;
  final String? initialSearchDescriptionMatches;
  final String? initialSearchCreatorName;
  final int? initialSearchCreatorId;
  final bool? initialSearchIsActive;
  final e621.PoolCategory? initialSearchCategory;
  final e621.PoolOrder? initialSearchOrder;
  final int? initialLimit;
  final bool initiallyExpanded;
  final bool hasInitialSearch;
  final int? limit;
  final void Function(e621.Pool pool) onSelected;
  // final bool Function(e621.Pool pool)? disableResults;
  final bool Function(e621.Pool pool)? filterResults;
  final Future<bool> Function(e621.Pool pool)? filterResultsAsync;
  final Future<List<e621.Pool>> Function(List<e621.Pool> pool)?
      customFilterResultsAsync;
  const WSearchPool({
    super.key,
    required this.onSelected,
    this.initialSearchNameMatches,
    this.initialSearchId,
    this.initialSearchDescriptionMatches,
    this.initialSearchCreatorName,
    this.initialSearchCreatorId,
    this.initialSearchIsActive,
    this.initialSearchCategory,
    this.initialSearchOrder,
    this.initialLimit,
    this.initiallyExpanded = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
  }) : hasInitialSearch = true;
  const WSearchPool.noInitialSearch({
    super.key,
    required this.onSelected,
    this.initiallyExpanded = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
  })  : hasInitialSearch = false,
        initialSearchNameMatches = null,
        initialSearchId = null,
        initialSearchDescriptionMatches = null,
        initialSearchCreatorName = null,
        initialSearchCreatorId = null,
        initialSearchIsActive = null,
        initialSearchCategory = null,
        initialSearchOrder = null,
        initialLimit = null;

  @override
  State<WSearchPool> createState() => _WSearchPoolState();
}

class _WSearchPoolState extends State<WSearchPool> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WSearchPoolState").logger;
  late PoolSearchParameterModel p;

  late ExpansionTileController _control;
  String? get searchNameMatches => p.searchNameMatches;
  set searchNameMatches(String? value) => p.searchNameMatches = value;
  List<int>? get searchId => p.searchId;
  set searchId(List<int>? value) => p.searchId = value;
  String? get searchDescriptionMatches => p.searchDescriptionMatches;
  set searchDescriptionMatches(String? value) =>
      p.searchDescriptionMatches = value;
  String? get searchCreatorName => p.searchCreatorName;
  set searchCreatorName(String? value) => p.searchCreatorName = value;
  int? get searchCreatorId => p.searchCreatorId;
  set searchCreatorId(int? value) => p.searchCreatorId = value;
  bool? get searchIsActive => p.searchIsActive;
  set searchIsActive(bool? value) => p.searchIsActive = value;
  e621.PoolCategory? get searchCategory => p.searchCategory;
  set searchCategory(e621.PoolCategory? value) => p.searchCategory = value;
  e621.PoolOrder? get searchOrder => p.searchOrder;
  set searchOrder(e621.PoolOrder? value) => p.searchOrder = value;
  int? get limit => p.limit;
  set limit(int? value) => p.limit = value;
  Future<List<e621.Pool>>? loadingPools;
  List<e621.Pool>? pools;
  @override
  void initState() {
    super.initState();
    p = PoolSearchParameterModel(
      searchNameMatches: widget.initialSearchNameMatches,
      searchId: widget.initialSearchId,
      searchDescriptionMatches: widget.initialSearchDescriptionMatches,
      searchCreatorName: widget.initialSearchCreatorName,
      searchCreatorId: widget.initialSearchCreatorId,
      searchIsActive: widget.initialSearchIsActive,
      searchCategory: widget.initialSearchCategory,
      searchOrder: widget.initialSearchOrder,
      limit: widget.initialLimit,
    );
    _control = ExpansionTileController();
    if (widget.hasInitialSearch) launchSearch(false);
    // if (widget.initiallyExpanded) _control.expand();
  }

  void launchSearch([bool collapse = true]) {
    setState(() {
      pools = null;
      loadingPools = e621
          .initPoolSearch(
            searchNameMatches: searchNameMatches,
            searchIds: searchId,
            searchDescriptionMatches: searchDescriptionMatches,
            searchCreatorName: searchCreatorName,
            searchCreatorId: searchCreatorId,
            searchIsActive: searchIsActive,
            searchCategory: searchCategory,
            searchOrder: searchOrder,
            limit: limit,
            credentials: E621AccessData.allowedUserDataSafe?.cred,
          )
          .send()
          .then((v) async {
            return v.stream
                .bytesToString()
                .then((e) => e621.Pool.fromRawJsonResults(e));
            //.then((t) => jsonDecode(t)).then((step) => (step as List).map((e) => e621.Pool.fromRawJson(e)).toList());
            // return (step as List).map((e) => e621.Pool.fromJson(e)).toList();
          })
          .then((v) =>
              widget.filterResults == null ? v : v.where(widget.filterResults!))
          .then((v) async {
            if (widget.filterResultsAsync == null) return v.toList();
            // final f =
            //     await Future.wait(v.map((e) => widget.filterResultsAsync!(e)));
            // // for (var i = 0; i < v.length; i++) {
            // //   if (f[i])
            // // }
            // return f.indexed.where((e)=> e.$2).map((e)=>v[e.$1]).toList();
            final r = <e621.Pool>[];
            for (var e in v) {
              if (await widget.filterResultsAsync!(e)) r.add(e);
            }
            return r;
          })
          .onError((e, s) {
            logger.severe(e, e, s);
            return <e621.Pool>[];
          })
        ..then((v) {
          setState(() {
            pools = v;
            loadingPools = null;
          });
        }).ignore();
      if (collapse) _control.collapse();
    });
  }

  static const _categoryText = ["Series", "Collection", "Any"];
  static String displayCategory(e621.PoolCategory? searchCategory) =>
      switch (searchCategory) {
        e621.PoolCategory.series => _categoryText[0],
        e621.PoolCategory.collection => _categoryText[1],
        _ => _categoryText[2],
      };
  static e621.PoolCategory? determineCategory(bool? searchCategory) =>
      switch (searchCategory) {
        true => e621.PoolCategory.series,
        false => e621.PoolCategory.collection,
        null => null,
      };
  static bool? determineCategoryVal(e621.PoolCategory? searchCategory) =>
      switch (searchCategory) {
        e621.PoolCategory.series => true,
        e621.PoolCategory.collection => false,
        null => null,
      };
  String get categoryText => displayCategory(searchCategory);
  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: double.maxFinite,
      child: ListView(
        children: [
          AppBar(title: const Text("Pools")),
          ExpansionTile(
            title: const Text("Search Options"),
            controller: _control,
            dense: true,
            initiallyExpanded: widget.initiallyExpanded,
            children: [
              ListTile(
                title: TextField(
                  maxLines: 1,
                  onChanged: (v) => searchNameMatches = v,
                  decoration:
                      const InputDecoration.collapsed(hintText: "Pool Name"),
                  controller: searchNameMatches != null
                      ? TextEditingController(text: searchNameMatches!)
                      : null,
                ),
              ),
              ListTile(
                title: TextField(
                  maxLines: 1,
                  onChanged: (v) => searchId = v
                      .replaceAll(RegExp("[^0-9]+"), " ")
                      .trim()
                      .split(" ")
                      .map((e) => int.parse(e))
                      .toList(),
                  decoration: const InputDecoration.collapsed(
                      hintText: "Pool Ids (comma separated list)"),
                  controller: searchId != null
                      ? TextEditingController(text: searchId!.join(", "))
                      : null,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) =>
                        TextEditingValue(
                            text: newValue.text
                                .replaceAll(RegExp("[^0-9, ]+"), ""),
                            selection: TextSelection.collapsed(
                                offset: newValue.selection.start)))
                  ],
                ),
              ),
              ListTile(
                title: TextField(
                  maxLines: 1,
                  onChanged: (v) => searchDescriptionMatches = v,
                  decoration: const InputDecoration.collapsed(
                      hintText: "Pool Description"),
                  controller: searchDescriptionMatches != null
                      ? TextEditingController(text: searchDescriptionMatches!)
                      : null,
                ),
              ),
              ListTile(
                title: TextField(
                  maxLines: 1,
                  onChanged: (v) => searchCreatorName = v,
                  decoration: const InputDecoration.collapsed(
                      hintText: "Pool Creator Name"),
                  controller: searchCreatorName != null
                      ? TextEditingController(text: searchCreatorName!)
                      : null,
                ),
              ),
              w.WIntegerField(
                name: "Pool Creator Id",
                getVal: () => searchCreatorId ?? -1,
                setVal: (v) => searchCreatorId = v,
                validateVal: (p1) => p1 != null && p1 >= 0,
              ),
              w.WBooleanTristateField(
                name: "Pool Is Active",
                subtitle: "${searchIsActive ?? "N/A"}",
                getVal: () =>
                    searchIsActive /*  == true
                    ? true
                    : searchIsActive ?? true
                        ? false
                        : null */
                ,
                setVal: (v) => searchIsActive =
                    v /*  == true
                    ? true
                    : v ?? true
                        ? false
                        : null */
                ,
              ),
              w.WBooleanTristateField(
                name: "Pool Category",
                subtitle: categoryText,
                getVal: () => determineCategoryVal(searchCategory),
                setVal: (v) => searchCategory = determineCategory(v),
              ),
              w.WEnumField(
                name: "Order",
                getVal: () => searchOrder ?? e621.PoolOrder.updatedAt,
                setVal: (Enum v) => searchOrder = v as e621.PoolOrder,
                values: e621.PoolOrder.values,
              ),
              w.WIntegerField(
                name: "Limit",
                getVal: () => limit ?? 50,
                setVal: (v) => limit = v,
                validateVal: (p1) => p1 != null && p1 > 0 && p1 <= 320,
              ),
              w.WIntegerField(
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
          if (loadingPools != null)
            const AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            ),
          if (loadingPools == null && pools == null)
            if (pools!.firstOrNull == null)
              const Text("No Results")
            else
              Text("${pools!.length} Results"),
          if (pools?.firstOrNull != null)
            ...pools!.map((e) {
              return WPoolTile(
                pool: e,
                onSelected: widget.onSelected,
              );
            }),
        ],
      ),
    );
  }
}

class WPoolTile extends StatelessWidget {
  const WPoolTile({
    super.key,
    required this.pool,
    required this.onSelected,
  });

  final e621.Pool pool;

  final void Function(e621.Pool pool) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("${pool.id}: ${pool.name}"),
      subtitle:
          Text("Posts: ${pool.postCount}, Last Updated: ${pool.updatedAt}"),
      onTap: () => onSelected(pool),
    );
  }
}

class PoolSearchParameterModel extends ChangeNotifier
    with PageSearchParameterNullable {
  String? _searchNameMatches;
  String? get searchNameMatches => _searchNameMatches;
  set searchNameMatches(String? value) {
    _searchNameMatches = value;
    notifyListeners();
  }

  List<int>? _searchId;
  List<int>? get searchId => _searchId;
  set searchId(List<int>? value) {
    _searchId = value;
    notifyListeners();
  }

  String? _searchDescriptionMatches;
  String? get searchDescriptionMatches => _searchDescriptionMatches;
  set searchDescriptionMatches(String? value) {
    _searchDescriptionMatches = value;
    notifyListeners();
  }

  String? _searchCreatorName;
  String? get searchCreatorName => _searchCreatorName;
  set searchCreatorName(String? value) {
    _searchCreatorName = value;
    notifyListeners();
  }

  int? _searchCreatorId;
  int? get searchCreatorId => _searchCreatorId;
  set searchCreatorId(int? value) {
    _searchCreatorId = value;
    notifyListeners();
  }

  bool? _searchIsActive;
  bool? get searchIsActive => _searchIsActive;
  set searchIsActive(bool? value) {
    _searchIsActive = value;
    notifyListeners();
  }

  e621.PoolCategory? _searchCategory;
  e621.PoolCategory? get searchCategory => _searchCategory;
  set searchCategory(e621.PoolCategory? value) {
    _searchCategory = value;
    notifyListeners();
  }

  e621.PoolOrder? _searchOrder;
  e621.PoolOrder? get searchOrder => _searchOrder;
  set searchOrder(e621.PoolOrder? value) {
    _searchOrder = value;
    notifyListeners();
  }

  int? _limit;
  int? get limit => _limit;
  set limit(int? value) {
    _limit = value;
    notifyListeners();
  }

  String? _page;
  @override
  String? get page => _page;
  set page(String? value) {
    _page = value;
    notifyListeners();
  }

  set pageNumber(int? value) {
    // if (isValidPage(value?.toString() ?? "1")) {
    //   _page = value?.toString();
    //   notifyListeners();
    // }
    _page = value?.toString();
    notifyListeners();
  }

  PoolSearchParameterModel({
    String? searchNameMatches,
    List<int>? searchId,
    String? searchDescriptionMatches,
    String? searchCreatorName,
    int? searchCreatorId,
    bool? searchIsActive,
    e621.PoolCategory? searchCategory,
    e621.PoolOrder? searchOrder,
    int? limit,
    String? page,
  })  : _page = page,
        _limit = limit,
        _searchOrder = searchOrder,
        _searchCategory = searchCategory,
        _searchIsActive = searchIsActive,
        _searchCreatorId = searchCreatorId,
        _searchCreatorName = searchCreatorName,
        _searchDescriptionMatches = searchDescriptionMatches,
        _searchNameMatches = searchNameMatches,
        _searchId = searchId;
}
