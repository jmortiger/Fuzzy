import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:fuzzy/web/models/e621/e6_models.dart';

void main() {
  test("Posts dejsonification", () async {
    var res = await http.get(
        Uri.parse("https://e621.net/posts.json?tags=fluffy+rating:s&limit=10"));
    // dynamic t = json.decode(res.body) as Map<String, dynamic>;
    var t = json.decode(res.body) as Map<String, dynamic>;
    // expect(t.runtimeType, isA<Map>);
    // expect(t.runtimeType, isA<Map<String, dynamic>>);
    expect(t["posts"].runtimeType, List);
    // print(t);
    var t2 = E6Posts.fromJson(t);
    // expect(t.posts[0].runtimeType, E6PostResponse);
    expect(t2.posts.first.runtimeType, E6PostResponse);
  });
}
