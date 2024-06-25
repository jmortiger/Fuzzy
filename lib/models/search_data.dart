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
  }) : searchString = tagList.fold("", (acc, e) => "$acc$e"),
        tagSet = tagList.toSet();
  factory SearchData.fromJson(String json) => SearchData.fromString(
      searchString: json,
    );
  String toJson() => searchString;
}
