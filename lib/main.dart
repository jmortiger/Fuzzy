import 'package:flutter/material.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/widgets/w_search_view.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

void main() {
  // var t = E621ApiEndpoints.dbExportTags.getMoreData().genRequest();
  E621ApiEndpoints.dbExportTags.getMoreData().sendRequest()
    ..catchError((error, stackTrace) => print(error))
    ..then(
      (value) => value.stream.toBytes().then((v) {
        print("Tag Database Received!");
        return http.ByteStream.fromBytes(
                GZipDecoder().decodeBytes(v.toList(growable: false)))
            .bytesToString()
            .then((vf) {
          print("Tag Database Decompressed!");
          return TagDB.makeFromCsvString(vf)
              .then((valueFINALLY) => util.tagDb.item = valueFINALLY);
        });
      }),
    );
  runApp(
      // MainApp(),
      MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: const Text("Fuzzy"),
      ),
      body: const WSearchView(),
    ),
  ));
}

// class MainApp extends StatefulWidget {
//   // final Future<http.StreamedResponse> waiting =
//   //     E621ApiEndpoints.searchPosts.getMoreData().genRequest(
//   //   query: {
//   //     "limit": (0, {"LIMIT": 2}),
//   //     "tags": (0, {"SEARCH_STRING": "jun_kobayashi "}),
//   //   },
//   //   /* headers: {
//   //   ""
//   // } */
//   // ).send();
//   const MainApp({super.key});

//   @override
//   State<MainApp> createState() => _MainAppState();
// }

// class _MainAppState extends State<MainApp> {
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       home: Scaffold(
//         body: Center(
//           child:
//               WSearchView(), /* FutureBuilder<http.StreamedResponse>(
//             future: widget.waiting,
//             builder: (cxt, snapshot) {
//               if (snapshot.hasData) {
//                 return WPostSearchResults(
//                     posts: snapshot.data!.stream.bytesToString().then((value) =>
//                         E6Posts.fromJson(
//                             json.decode(value) as Map<String, dynamic>)));
//               } else if (snapshot.hasError) {
//                 return Text(snapshot.error.toString());
//               }
//               return const CircularProgressIndicator();
//             },
//           ), */ //WPostSearchResults(posts: ),
//         ),
//       ),
//     );
//   }
// }
