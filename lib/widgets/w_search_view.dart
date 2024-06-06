import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:http/http.dart' as http;
import 'package:fuzzy/util/util.dart' as util;

class WSearchView extends StatefulWidget {
  const WSearchView({super.key});

  http.Request deliverSearchRequest({
    String tags = "jun_kobayashi rating:safe",
    int limit = 50,
    String? page,
  }) =>
      E621ApiEndpoints.searchPosts.getMoreData().genRequest(
        query: {
          "limit": (0, {"LIMIT": limit}),
          "tags": (0, {"SEARCH_STRING": tags}),
        },
      );

  @override
  State<WSearchView> createState() => _WSearchViewState();
}

class _WSearchViewState extends State<WSearchView> {
  String searchText = "";
  Future<http.StreamedResponse>? pr;
  E6Posts? posts;
  @override
  Widget build(BuildContext context) {
    // if (!util.tagDb.isAssigned) {
    //   E621ApiEndpoints.dbExportTags.getMoreData().sendRequest()
    //     ..catchError((error, stackTrace) {
    //       print(error);
    //     })
    //     ..then(
    //       (value) {
    //         print(value);
    //         // value.stream//.bytesToString()
    //         value.stream.toBytes().then((v) {
    //           print(v);
    //           return http.ByteStream.fromBytes(
    //                   GZipDecoder().decodeBytes(v.toList(growable: false)))
    //               .bytesToString()
    //               .then((vf) {
    //             print(vf);
    //             return util.tagDb.item = TagDB.fromCsvString(vf);
    //           });
    //         });
    //         // GZipDecoder().decodeBuffer(InputStream((await value.stream.toBytes()).toList(growable: false)))
    //       },
    //     );
    // }
    return Column(
      children: [
        TextField(
          // inputFormatters: [
          //   TextInputFormatter.withFunction((oldValue, newValue) {
          //     // if (util.tagDb.itemSafe != null) {
          //     //   util.tagDb.itemSafe!.tagSet.where((element) => element.startsWith(oldValue))
          //     // }
          //   })
          // ],
          autofillHints: util.tagDb.itemSafe?.tagSet,
          onChanged: (value) => setState(() => searchText = value),
          onSubmitted: (value) => setState(() {
            pr = widget.deliverSearchRequest(tags: value).send();
          }),
        ),
        if (posts == null && pr != null)
          Expanded(
            child: FutureBuilder<http.StreamedResponse>(
              future: pr,
              builder: (cxt, snapshot) {
                if (snapshot.hasData) {
                  return WPostSearchResultsFuture(
                      posts: snapshot.data!.stream.bytesToString().then(
                          (value) => E6Posts.fromJson(
                              json.decode(value) as Map<String, dynamic>)));
                } else if (snapshot.hasError) {
                  return Text(snapshot.error.toString());
                }
                return pr != null
                    ? const CircularProgressIndicator()
                    : const Placeholder();
              },
            ),
          ),
        if (posts != null)
          (() {
            pr = null;
            return Expanded(
              child: WPostSearchResults(posts: posts!),
            );
          })()
      ],
    );
  }
}
// class WSearchResults extends StatefulWidget {

//   const WSearchResults({super.key});

//   @override
//   State<WSearchResults> createState() => _WSearchResultsState();
// }

// class _WSearchResultsState extends State<WSearchResults> {
//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }
// }
