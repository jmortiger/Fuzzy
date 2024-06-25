import 'dart:convert';

import 'package:test/test.dart';
import 'package:test/test.dart' as tst;

import 'package:fuzzy/models/app_settings.dart';

void main() {
  group("Serialization", () {
    test("AppSettings.default", () {
      var a = AppSettings.defaultSettings;
      try {
        expect(jsonEncode(AppSettings.fromJson(jsonDecode(jsonEncode(a)))), tst.equals(jsonEncode(a)));
      } catch (e) {
        expect(e, isNull);
        rethrow;
      }
    });
    test("PostViewData.default", () {
      var a = PostViewData.defaultData;
      try {
        expect(jsonEncode(PostView.fromJson(jsonDecode(jsonEncode(a)))), tst.equals(jsonEncode(a)));
      } catch (e) {
        expect(e, isNull);
        rethrow;
      }
    });
    test("SearchViewData.default", () {
      var a = SearchViewData.defaultData;
      try {
        expect(jsonEncode(SearchViewData.fromJson(jsonDecode(jsonEncode(a)))), tst.equals(jsonEncode(a)));
      } catch (e) {
        expect(e, isNull);
        rethrow;
      }
    });
  });
}
