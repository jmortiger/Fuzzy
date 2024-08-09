import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/web/e621/post_search_parameters.dart';
import 'package:http/http.dart';
import 'package:j_util/e621.dart' as e621;
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

  final void Function(e621.PostSet set) onSelected;
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
  }) : hasInitialSearch = true;
  const WSearchSet.noInitialSearch({
    super.key,
    required this.onSelected,
    this.initiallyExpanded = true,
    this.limit,
    this.filterResults,
    this.filterResultsAsync,
    this.customFilterResultsAsync,
  })  : hasInitialSearch = false,
        initialSearchName = null,
        initialSearchShortname = null,
        initialSearchCreatorName = null,
        initialSearchCreatorId = null,
        initialSearchOrder = null,
        initialLimit = null,
        initialPage = null;

  void _defaultOnSelected() {}

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
    if (widget.hasInitialSearch) launchSearch(false);
    // if (widget.initiallyExpanded) _control.expand();
  }

  void launchSearch([bool collapse = true]) {
    setState(() {
      sets = null;
      loadingSets = e621.Api.initSearchSetsRequest(
        searchName: searchName,
        searchShortname: searchShortname,
        searchCreatorName: searchCreatorName,
        searchCreatorId: searchCreatorId,
        searchOrder: searchOrder,
        limit: limit,
        page: page,
        credentials: E621AccessData.devAccessData.$.cred,
      ).send().then((v) async {
        var t = await ByteStream(v.stream.asBroadcastStream()).bytesToString();
        var step = jsonDecode(t);
        try {
          return (step as List).mapAsList(
            (e, index, list) => e621.PostSet.fromJson(e),
          );
        } catch (e) {
          return <e621.PostSet>[];
        }
      })
        ..then((v) async {
          if (widget.filterResultsAsync == null) return v;
          final r = <e621.PostSet>[];
          for (var e in v) {
            if (await widget.filterResultsAsync!(e)) r.add(e);
          }
          return r;
        })
        ..then((v) {
          setState(() {
            sets = widget.filterResults == null
                ? v
                : v.where(widget.filterResults!).toList();
            loadingSets = null;
          });
        });
      if (collapse) _control.collapse();
    });
  }

  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: double.maxFinite,
      child: ListView(
        children: [
          AppBar(title: const Text("Sets")),
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
                  decoration:
                      const InputDecoration.collapsed(hintText: "Set Name"),
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
                setVal: (v) => p.page = v.toString(),
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
                onSelected: widget.onSelected,
              );
            }),
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
    );
  }
}

class SetSearchParameterModel with PageSearchParameter {
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
}

class SetSearchParameterNotifier extends ChangeNotifier
    with PageSearchParameter
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
}
