import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

class WSearchSet extends StatefulWidget {
  final String? initialSearchName;
  final String? initialSearchShortname;
  final String? initialSearchCreatorName;
  final e621.SetOrder? initialSearchOrder;
  final int? initialLimit;
  final String? initialPage;
  const WSearchSet({
    super.key,
    this.initialSearchName,
    this.initialSearchShortname,
    this.initialSearchCreatorName,
    this.initialSearchOrder,
    this.initialLimit,
    this.initialPage,
  });

  void _defaultOnSelected() {}

  @override
  State<WSearchSet> createState() => _WSearchSetState();
}

class _WSearchSetState extends State<WSearchSet> {
  String? searchName;
  String? searchShortname;
  String? searchCreatorName;
  e621.SetOrder? searchOrder;
  int? limit;
  String? page;

  Future<List<e621.Set>>? loadingSets;
  List<e621.Set>? sets;
  _WSearchSetState() {
    searchName = widget.initialSearchName;
    searchShortname = widget.initialSearchShortname;
    searchCreatorName = widget.initialSearchCreatorName;
    searchOrder = widget.initialSearchOrder;
    limit = widget.initialLimit;
    page = widget.initialPage;
    loadingSets = e621.Api.initSearchSetsRequest(
      searchName: widget.initialSearchName,
      searchShortname: widget.initialSearchShortname,
      searchCreatorName: widget.initialSearchCreatorName,
      searchOrder: widget.initialSearchOrder,
      limit: widget.initialLimit,
      page: widget.initialPage,
    ).send().then((v) async {
      var t = await ByteStream(v.stream.asBroadcastStream()).bytesToString();
      // return Response(
      //   t,
      //   v.statusCode,
      //   headers: v.headers,
      //   isRedirect: v.isRedirect,
      //   persistentConnection: v.persistentConnection,
      //   reasonPhrase: v.reasonPhrase,
      //   request: v.request,
      // );
      loadingSets = null;
      return sets = (jsonDecode(t) as List).mapAsList(
        (e, index, list) => e621.Set.fromJson(e),
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AppBar(
          title: const Text("Sets"),
          actions: const [
            // TODO: Filter buttons
          ],
        ),
        if (loadingSets != null) const CircularProgressIndicator(),
        if (sets != null) ...sets!.map((e) => WSetTile(set: e)),
      ],
    );
  }

  Future<List<e621.Set>> sendSearch() =>
      loadingSets = e621.Api.initSearchSetsRequest(
        searchName: widget.initialSearchName,
        searchShortname: widget.initialSearchShortname,
        searchCreatorName: widget.initialSearchCreatorName,
        searchOrder: widget.initialSearchOrder,
        limit: widget.initialLimit,
        page: widget.initialPage,
      ).send().then((v) async {
        var t = await ByteStream(v.stream.asBroadcastStream()).bytesToString();
        // return Response(
        //   t,
        //   v.statusCode,
        //   headers: v.headers,
        //   isRedirect: v.isRedirect,
        //   persistentConnection: v.persistentConnection,
        //   reasonPhrase: v.reasonPhrase,
        //   request: v.request,
        // );
        loadingSets = null;
        return sets = (jsonDecode(t) as List).mapAsList(
          (e, index, list) => e621.Set.fromJson(e),
        );
      });
}

class WSetTile extends StatelessWidget {
  const WSetTile({
    super.key,
    required this.set,
  });

  final e621.Set set;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("${set.id}: ${set.name}"),
      subtitle: Text("Posts: ${set.postCount}, Last Updated: ${set.updatedAt}"),
    );
  }
}
