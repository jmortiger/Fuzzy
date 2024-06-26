import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:http/http.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

class WSearchSet extends StatefulWidget {
  final String? initialSearchName;
  final String? initialSearchShortname;
  final String? initialSearchCreatorName;
  final e621.SetOrder? initialSearchOrder;
  final int? initialLimit;
  final String? initialPage;

  final void Function(e621.Set set) onSelected;
  const WSearchSet({
    super.key,
    required this.onSelected,
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
  SetSearchParameterModel p = SetSearchParameterModel();
  // late ChangeNotifierProvider prov;
  String? get searchName => p.searchName;
  set searchName(String? value) => p.searchName = value;
  String? get searchShortname => p.searchShortname;
  set searchShortname(String? value) => p.searchShortname = value;
  String? get searchCreatorName => p.searchCreatorName;
  set searchCreatorName(String? value) => p.searchCreatorName = value;
  e621.SetOrder? get searchOrder => p.searchOrder;
  set searchOrder(e621.SetOrder? value) => p.searchOrder = value;
  int? get limit => p.limit;
  set limit(int? value) => p.limit = value;
  String? get page => p.page;
  set page(String? value) => p.page = value;

  Future<List<e621.Set>>? loadingSets;
  List<e621.Set>? sets;
  @override
  void initState() {
    super.initState();
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
      credentials: E621AccessData.devData.$.cred,
    ).send().then((v) async {
      var t = await ByteStream(v.stream.asBroadcastStream()).bytesToString();
      var step = jsonDecode(t);
      try {
        return (step as List).mapAsList(
          (e, index, list) => e621.Set.fromJson(e),
        );
      } catch (e) {
        return <e621.Set>[];
      }
    })
      ..then((v) {
        setState(() {
          sets = v;
          loadingSets = null;
        });
      });
    // prov = ChangeNotifierProvider(
    //     create: (context) => p,
    //     builder: (context, child) {
    //       return const WSetSearchParameters();
    //     });
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
            // title: ExpansionPanelList(
            //   expansionCallback: (panelIndex, isExpanded) => setState(() {
            //     this.isExpanded = isExpanded;
            //   }),
            //   children: [
            //     ExpansionPanel(
            //       headerBuilder: (context, isExpanded) {
            //         return const Text("Sets");
            //       },
            //       isExpanded: isExpanded,
            //       body: ListView(
            //         children: [
            //           Row(
            //             children: [
            //               const Text("Set Name"),
            //               TextField(
            //                 maxLines: 1,
            //                 onChanged: (v) => searchName = v,
            //                 controller: searchName != null
            //                     ? TextEditingController(text: searchName!)
            //                     : null,
            //               ),
            //             ],
            //           ),
            //           Row(
            //             children: [
            //               const Text("Set Shortname"),
            //               TextField(
            //                 maxLines: 1,
            //                 onChanged: (v) => searchShortname = v,
            //                 controller: searchShortname != null
            //                     ? TextEditingController(text: searchShortname!)
            //                     : null,
            //               ),
            //             ],
            //           ),
            //           Row(
            //             children: [
            //               const Text("Set CreatorName"),
            //               TextField(
            //                 maxLines: 1,
            //                 onChanged: (v) => searchCreatorName = v,
            //                 controller: searchCreatorName != null
            //                     ? TextEditingController(
            //                         text: searchCreatorName!,
            //                       )
            //                     : null,
            //               ),
            //             ],
            //           ),
            //           // TODO: Allow order changing
            //           // Row(
            //           //   children: [
            //           //     const Text("Set Order"),
            //           //     TextField(
            //           //       maxLines: 1,
            //           //       onChanged: (v) => searchOrder = v,
            //           //       controller: searchOrder != null
            //           //           ? TextEditingController(
            //           //               text: searchOrder!.toString(),
            //           //             )
            //           //           : null,
            //           //     ),
            //           //   ],
            //           // ),
            //           Row(
            //             children: [
            //               const Text("limit"),
            //               TextField(
            //                 maxLines: 1,
            //                 onChanged: (v) => limit = int.tryParse(v) ?? limit,
            //                 controller: limit != null
            //                     ? TextEditingController(text: limit!.toString())
            //                     : null,
            //                 keyboardType: TextInputType.number,
            //               ),
            //             ],
            //           ),
            //           Row(
            //             children: [
            //               const Text("page"),
            //               TextField(
            //                 maxLines: 1,
            //                 onChanged: (v) => page = v,
            //                 controller: page != null
            //                     ? TextEditingController(text: page!)
            //                     : null,
            //               ),
            //             ],
            //           ),
            //         ],
            //       ),
            //     ),
            //   ],
            // ),
            actions: const [
              // TODO: Filter buttons
            ],
          ),
          // if (isExpanded)
          //   ListView(
          //     children: [
          //       Row(
          //         children: [
          //           const Text("Set Name"),
          //           TextField(
          //             maxLines: 1,
          //             onChanged: (v) => searchName = v,
          //             controller: searchName != null
          //                 ? TextEditingController(text: searchName!)
          //                 : null,
          //           ),
          //         ],
          //       ),
          //       Row(
          //         children: [
          //           const Text("Set Shortname"),
          //           TextField(
          //             maxLines: 1,
          //             onChanged: (v) => searchShortname = v,
          //             controller: searchShortname != null
          //                 ? TextEditingController(text: searchShortname!)
          //                 : null,
          //           ),
          //         ],
          //       ),
          //       Row(
          //         children: [
          //           const Text("Set CreatorName"),
          //           TextField(
          //             maxLines: 1,
          //             onChanged: (v) => searchCreatorName = v,
          //             controller: searchCreatorName != null
          //                 ? TextEditingController(
          //                     text: searchCreatorName!,
          //                   )
          //                 : null,
          //           ),
          //         ],
          //       ),
          //       // TODO: Allow order changing
          //       // Row(
          //       //   children: [
          //       //     const Text("Set Order"),
          //       //     TextField(
          //       //       maxLines: 1,
          //       //       onChanged: (v) => searchOrder = v,
          //       //       controller: searchOrder != null
          //       //           ? TextEditingController(
          //       //               text: searchOrder!.toString(),
          //       //             )
          //       //           : null,
          //       //     ),
          //       //   ],
          //       // ),
          //       Row(
          //         children: [
          //           const Text("limit"),
          //           TextField(
          //             maxLines: 1,
          //             onChanged: (v) => limit = int.tryParse(v) ?? limit,
          //             controller: limit != null
          //                 ? TextEditingController(text: limit!.toString())
          //                 : null,
          //             keyboardType: TextInputType.number,
          //           ),
          //         ],
          //       ),
          //       Row(
          //         children: [
          //           const Text("page"),
          //           TextField(
          //             maxLines: 1,
          //             onChanged: (v) => page = v,
          //             controller: page != null
          //                 ? TextEditingController(text: page!)
          //                 : null,
          //           ),
          //         ],
          //       ),
          //     ],
          //   ),
          // prov,
          if (loadingSets != null)
            const AspectRatio(
              aspectRatio: 1,
              child: CircularProgressIndicator(),
            ),
          if (sets?.firstOrNull == null) const Text("No Results"),
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

  Future<List<e621.Set>> sendSearch() =>
      loadingSets = e621.Api.initSearchSetsRequest(
        searchName: searchName,
        searchShortname: searchShortname,
        searchCreatorName: searchCreatorName,
        searchOrder: searchOrder,
        limit: limit,
        page: page,
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
        loadingSets = null;
        return sets = (jsonDecode(t) as List).mapAsList(
          (e, index, list) => e621.Set.fromJson(e),
        );
      }).onError(onErrorPrintAndRethrow);
}

class WSetTile extends StatelessWidget {
  const WSetTile({
    super.key,
    required this.set,
    required this.onSelected,
  });

  final e621.Set set;

  final void Function(e621.Set set) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("${set.id}: ${set.name}"),
      subtitle: Text("Posts: ${set.postCount}, Last Updated: ${set.updatedAt}"),
      onTap: () => onSelected(set),
    );
  }
}

class SetSearchParameterModel extends ChangeNotifier {
  SetSearchParameterModel({
    String? searchName,
    String? searchShortname,
    String? searchCreatorName,
    e621.SetOrder? searchOrder,
    int? limit,
    String? page,
  })  : _searchName = searchName,
        _searchShortname = searchShortname,
        _searchCreatorName = searchCreatorName,
        _searchOrder = searchOrder,
        _limit = limit,
        _page = page;

  String? _searchName;

  String? get searchName => _searchName;

  set searchName(String? value) {
    _searchName = value;
    notifyListeners();
  }

  String? _searchShortname;

  String? get searchShortname => _searchShortname;

  set searchShortname(String? value) {
    _searchShortname = value;
    notifyListeners();
  }

  String? _searchCreatorName;

  String? get searchCreatorName => _searchCreatorName;

  set searchCreatorName(String? value) {
    _searchCreatorName = value;
    notifyListeners();
  }

  e621.SetOrder? _searchOrder;

  e621.SetOrder? get searchOrder => _searchOrder;

  set searchOrder(e621.SetOrder? value) {
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
}

// class WSetSearchParameters extends StatefulWidget {
//   const WSetSearchParameters({super.key});

//   @override
//   State<WSetSearchParameters> createState() => _WSetSearchParametersState();
// }

// class _WSetSearchParametersState extends State<WSetSearchParameters> {
//   bool isExpanded = false;
//   SetSearchParameterModel get p =>
//       Provider.of<SetSearchParameterModel>(context, listen: false);
//   String? get searchName => p.searchName;
//   set searchName(String? value) => p.searchName = value;
//   String? get searchShortname => p.searchShortname;
//   set searchShortname(String? value) => p.searchShortname = value;
//   String? get searchCreatorName => p.searchCreatorName;
//   set searchCreatorName(String? value) => p.searchCreatorName = value;
//   e621.SetOrder? get searchOrder => p.searchOrder;
//   set searchOrder(e621.SetOrder? value) => p.searchOrder = value;
//   int? get limit => p.limit;
//   set limit(int? value) => p.limit = value;
//   String? get page => p.page;
//   set page(String? value) => p.page = value;
//   @override
//   Widget build(BuildContext context) {
//     return ExpansionPanelList(
//       expansionCallback: (panelIndex, isExpanded) => setState(() {
//         this.isExpanded = isExpanded;
//       }),
//       children: [
//         ExpansionPanel(
//           headerBuilder: (context, isExpanded) {
//             return const Text("Sets");
//           },
//           isExpanded: isExpanded,
//           body: ListView(
//             children: [
//               Row(
//                 children: [
//                   const Text("Set Name"),
//                   TextField(
//                     maxLines: 1,
//                     onChanged: (v) => searchName = v,
//                     controller: searchName != null
//                         ? TextEditingController(text: searchName!)
//                         : null,
//                   ),
//                 ],
//               ),
//               Row(
//                 children: [
//                   const Text("Set Shortname"),
//                   TextField(
//                     maxLines: 1,
//                     onChanged: (v) => searchShortname = v,
//                     controller: searchShortname != null
//                         ? TextEditingController(text: searchShortname!)
//                         : null,
//                   ),
//                 ],
//               ),
//               Row(
//                 children: [
//                   const Text("Set CreatorName"),
//                   TextField(
//                     maxLines: 1,
//                     onChanged: (v) => searchCreatorName = v,
//                     controller: searchCreatorName != null
//                         ? TextEditingController(
//                             text: searchCreatorName!,
//                           )
//                         : null,
//                   ),
//                 ],
//               ),
//               // TODO: Allow order changing
//               // Row(
//               //   children: [
//               //     const Text("Set Order"),
//               //     TextField(
//               //       maxLines: 1,
//               //       onChanged: (v) => searchOrder = v,
//               //       controller: searchOrder != null
//               //           ? TextEditingController(
//               //               text: searchOrder!.toString(),
//               //             )
//               //           : null,
//               //     ),
//               //   ],
//               // ),
//               Row(
//                 children: [
//                   const Text("limit"),
//                   TextField(
//                     maxLines: 1,
//                     onChanged: (v) => limit = int.tryParse(v) ?? limit,
//                     controller: limit != null
//                         ? TextEditingController(text: limit!.toString())
//                         : null,
//                     keyboardType: TextInputType.number,
//                   ),
//                 ],
//               ),
//               Row(
//                 children: [
//                   const Text("page"),
//                   TextField(
//                     maxLines: 1,
//                     onChanged: (v) => page = v,
//                     controller: page != null
//                         ? TextEditingController(text: page!)
//                         : null,
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
