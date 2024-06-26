import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:http/http.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

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

  final void Function(e621.Pool pool) onSelected;
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
  });

  void _defaultOnSelected() {}

  @override
  State<WSearchPool> createState() => _WSearchPoolState();
}

class _WSearchPoolState extends State<WSearchPool> {
  PoolSearchParameterModel p = PoolSearchParameterModel();
  String? get searchNameMatches => p.searchNameMatches;
  set searchNameMatches(String? value) => p.searchNameMatches = value;
  List<int>? get searchId => p.searchId;
  set searchId(List<int>? value) => p.searchId = value;
  String? get searchDescriptionMatches => p.searchDescriptionMatches;
  set searchDescriptionMatches(String? value) => p.searchDescriptionMatches = value;
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
    searchNameMatches = widget.initialSearchNameMatches;
    searchId = widget.initialSearchId;
    searchDescriptionMatches = widget.initialSearchDescriptionMatches;
    searchCreatorName = widget.initialSearchCreatorName;
    searchCreatorId = widget.initialSearchCreatorId;
    searchIsActive = widget.initialSearchIsActive;
    searchCategory = widget.initialSearchCategory;
    searchOrder = widget.initialSearchOrder;
    limit = widget.initialLimit;
    loadingPools = e621.Api.initSearchPoolsRequest(
      searchNameMatches: searchNameMatches,
      searchId: searchId,
      searchDescriptionMatches: searchDescriptionMatches,
      searchCreatorName: searchCreatorName,
      searchCreatorId: searchCreatorId,
      searchIsActive: searchIsActive,
      searchCategory: searchCategory,
      searchOrder: searchOrder,
      limit: limit,
      credentials: E621AccessData.devData.$.cred,
    ).send().then((v) async {
      var t = await ByteStream(v.stream.asBroadcastStream()).bytesToString();
      var step = jsonDecode(t);
      try {
        return (step as List).mapAsList(
          (e, index, list) => e621.Pool.fromJson(e),
        );
      } catch (e) {
        return <e621.Pool>[];
      }
    })
      ..then((v) {
        setState(() {
          pools = v;
          loadingPools = null;
        });
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
          AppBar(
            title: const Text("Sets"),
            actions: const [
              // TODO: Filter buttons
            ],
          ),
          if (loadingPools != null)
            const AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            ),
          if (pools?.firstOrNull == null) const Text("No Results"),
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

  Future<List<e621.Pool>> sendSearch() =>
      loadingPools = e621.Api.initSearchPoolsRequest(
        searchNameMatches: searchNameMatches,
        searchId: searchId,
        searchDescriptionMatches: searchDescriptionMatches,
        searchCreatorName: searchCreatorName,
        searchCreatorId: searchCreatorId,
        searchIsActive: searchIsActive,
        searchCategory: searchCategory,
        searchOrder: searchOrder,
        limit: limit,
      ).send().onError(onErrorPrintAndRethrow).then((v) async {
        var t = await ByteStream(v.stream.asBroadcastStream())
            .bytesToString()
            .onError(onErrorPrintAndRethrow);
        // return Response(
        //   t,
        //   v.statusCode,
        //   headers: v.headers,
        //   isRedirect: v.isRedirect,
        //   persistentConnection: v.persistentConnection,
        //   reasonPhrase: v.reasonPhrase,
        //   request: v.request,
        // );
        loadingPools = null;
        return pools = (jsonDecode(t) as List).mapAsList(
          (e, index, list) => e621.Pool.fromJson(e),
        );
      }).onError(onErrorPrintAndRethrow);
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
      subtitle: Text("Posts: ${pool.postCount}, Last Updated: ${pool.updatedAt}"),
      onTap: () => onSelected(pool),
    );
  }
}

class PoolSearchParameterModel extends ChangeNotifier {
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

  String? get page => _page;

  set page(String? value) {
    _page = value;
    notifyListeners();
  }

  PoolSearchParameterModel({
    /* required  */String? searchNameMatches,
    /* required  */List<int>? searchId,
    /* required  */String? searchDescriptionMatches,
    /* required  */String? searchCreatorName,
    /* required  */int? searchCreatorId,
    /* required  */bool? searchIsActive,
    /* required  */e621.PoolCategory? searchCategory,
    /* required  */e621.PoolOrder? searchOrder,
    /* required  */int? limit,
    /* required  */String? page,
  }) : _page = page, _limit = limit, _searchOrder = searchOrder, _searchCategory = searchCategory, _searchIsActive = searchIsActive, _searchCreatorId = searchCreatorId, _searchCreatorName = searchCreatorName, _searchDescriptionMatches = searchDescriptionMatches, _searchNameMatches = searchNameMatches, _searchId = searchId;
}
