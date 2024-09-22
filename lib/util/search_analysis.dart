/// Used for advanced search bar suggestions
class SearchQueryAnalysis {
  final String query;
  late final Set<String> tokens;
  late final String formattedQuery;
  SearchQueryAnalysis(this.query) {
    if (query.isNotEmpty) {
      tokens = query.split(RegExp(r'\s+')).toSet()
        ..removeWhere((e) => e.isEmpty);
      formattedQuery = tokens.fold("", (p, e) => "$p $e").trim();
    } else {
      tokens = {};
      formattedQuery = "";
    }
  }
}

bool isPotentialMatch(
  String currentSearch,
  String potentialMatch, {
  final bool matchEmptySearch = true,
  final bool matchEmptyPotential = true,
}) {
  currentSearch = currentSearch.trim();
  if (currentSearch.isEmpty) return matchEmptySearch;
  potentialMatch = potentialMatch.trim();
  if (potentialMatch.isEmpty) return matchEmptyPotential;
  final curr = SearchQueryAnalysis(currentSearch),
      other = SearchQueryAnalysis(potentialMatch);
  if (other.tokens.length == 1) {
    return other.tokens.first.contains(
        RegExp(curr.tokens.fold("", (p, e) => "$p|$e").replaceFirst("|", "")));
  } else {
    for (final token in other.tokens) {
      if (token.contains(RegExp(
          curr.tokens.fold("", (p, e) => "$p|$e").replaceFirst("|", "")))) {
        return true;
      }
    }
    return false;
  }
}

/// TODO: Complete
class SearchQueryMatchData {
  final String query;
  final String match;
  final String formattedQuery;
  final String formattedMatch;
  final Set<String> queryTokens;
  final Set<String> matchTokens;
  final int indexOfMatchInQuery;
  final int indexOfMatchInMatch;
  final int lengthOfMatch;
  final int matchingTokens;

  const SearchQueryMatchData({
    required this.query,
    required this.match,
    required this.formattedQuery,
    required this.formattedMatch,
    required this.queryTokens,
    required this.matchTokens,
    required this.indexOfMatchInQuery,
    required this.indexOfMatchInMatch,
    required this.lengthOfMatch,
    required this.matchingTokens,
  });
  // static SearchQueryMatchData? findMatch(
  //   final String query,
  //   final String potentialMatch, {
  //   final bool matchEmptySearch = true,
  //   final bool matchEmptyPotential = true,
  // }) {
  //   if (!isPotentialMatch(
  //     query,
  //     potentialMatch,
  //     matchEmptyPotential: matchEmptyPotential,
  //     matchEmptySearch: matchEmptySearch,
  //   )) {
  //     return null;
  //   }
  //   final curr = SearchQueryAnalysis(query.trim()),
  //       other = SearchQueryAnalysis(potentialMatch.trim());
  //   var matchingTokens = 0;
  //   if (other.tokens.length == 1) {

  //     // return other.tokens.first.contains(RegExp(
  //     //     curr.tokens.fold("", (p, e) => "$p|$e").replaceFirst("|", "")));
  //   } else {
  //     for (final token in other.tokens) {
  //       if (token.contains(RegExp(
  //           curr.tokens.fold("", (p, e) => "$p|$e").replaceFirst("|", "")))) {
  //         return true;
  //       }
  //     }
  //     return false;
  //   }
  // }
}
