import 'package:j_util/j_util_full.dart';
/// TODO: Add date data
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
  })  : tagList = searchString.split(RegExp(r"\s")),
        tagSet = searchString.split(RegExp(r"\s")).toSet();
  SearchData.fromList({
    required this.tagList,
  })  : searchString = tagList.foldToString(),
        // })  : searchString = tagList.fold("", (acc, e) => acc.isNotEmpty ? "$acc $e" : e),
        tagSet = tagList.toSet();
  factory SearchData.fromJson(String json) => SearchData.fromString(
        searchString: json,
      );
  String toJson() => searchString;

  @override
  bool operator ==(Object other) {
    return other is SearchData && searchString == other.searchString;
  }

  @override
  int get hashCode => searchString.hashCode;
}

class SearchMetrics extends SearchData {
  final int frequency;
  const SearchMetrics.$const({
    required this.frequency,
    required super.searchString,
    required super.tagList,
    required super.tagSet,
  }) : super.$const();
  SearchMetrics.fromString({
    required this.frequency,
    required super.searchString,
  }) : super.fromString();
  SearchMetrics.fromList({
    required this.frequency,
    required super.tagList,
  }) : super.fromList();
  factory SearchMetrics.fromJson(Map<String, dynamic> json) =>
      SearchMetrics.fromString(
        frequency: json["frequency"],
        searchString: json["searchString"],
      );
  @override
  /* Map<String, dynamic> */ String toJson() => {
        "frequency": frequency.toString(),
        "searchString": searchString.toString(),
      }.toString();

  @override
  bool operator ==(Object other) {
    return other is SearchMetrics &&
        searchString == other.searchString &&
        frequency == other.frequency;
  }

  @override
  int get hashCode => searchString.hashCode;
}
