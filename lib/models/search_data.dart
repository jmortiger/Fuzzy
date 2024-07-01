import 'package:j_util/j_util_full.dart';

class SearchData {
  final String searchString;
  final List<String> tagList;
  final Set<String> tagSet;

  const SearchData.$const({
    required this.searchString,
    required this.tagList,
    required this.tagSet,
  });
  SearchData.fromString({
    required this.searchString,
  })  : tagList = searchString.split(RegExpExt.whitespace),
        tagSet = searchString.split(RegExpExt.whitespace).toSet();
  SearchData.fromList({
    required this.tagList,
  })  : searchString = tagList.fold("", (acc, e) => "$acc$e"),
        tagSet = tagList.toSet();
  factory SearchData.fromJson(String json) => SearchData.fromString(
        searchString: json,
      );
  String toJson() => searchString;
}

class SearchMetrics extends SearchData {
  final List<int> frequency;
  const SearchMetrics.$const({
    required this.frequency,
    required String searchString,
    required List<String> tagList,
    required Set<String> tagSet,
  }) : super.$const(
          searchString: searchString,
          tagList: tagList,
          tagSet: tagSet,
        );
  SearchMetrics.fromString({
    required this.frequency,
    required String searchString,
  }) : super.fromString(searchString: searchString);
  SearchMetrics.fromList({
    required this.frequency,
    required List<String> tagList,
  }) : super.fromList(tagList: tagList);
  factory SearchMetrics.fromJson(Map<String, dynamic> json) => SearchMetrics.fromString(
        frequency: (json["frequency"] as List).cast<int>(),
        searchString: json["searchString"],
      );
  @override
  /* Map<String, dynamic> */String toJson() => {
    "frequency": frequency.toString(),
    "searchString": searchString.toString(),
  }.toString();
}
