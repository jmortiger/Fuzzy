import 'package:e621/middleware.dart';
// import 'package:flutter/foundation.dart';

/// Used for advanced search bar suggestions
class SearchQueryAnalysis {
  final String query;
  late final Set<String> tokens;
  late final String formattedQuery;
  SearchQueryAnalysis(this.query) {
    if (query.trim().isNotEmpty) {
      tokens = query.split(RegExp(tagStartPosition)).fold(<String>[],
          (p, e) => (e = e.trim()).isNotEmpty ? (p..add(e)) : p).toSet();
      formattedQuery = tokens.join(" ");
    } else {
      tokens = {};
      formattedQuery = "";
    }
  }

  bool get isEmpty => tokens.isEmpty;

  bool matchesFully(String other) =>
      SearchQueryAnalysis(other).tokens.containsAll(tokens);

  /// All of this matches part of [other]
  bool matchesSectionOfOther(String other) =>
      SearchQueryAnalysis(other).tokens.intersection(tokens).length ==
      tokens.length;

  /// All of [other] matches part of this
  bool matchesSection(String other) {
    final o = SearchQueryAnalysis(other).tokens;
    return tokens.intersection(o).length == o.length;
  }

  bool hasIntersection(String other) =>
      SearchQueryAnalysis(other).tokens.any((e) => tokens.contains(e));

  /// If this is completely contained in [other], retrieves the parts of other not in this. Else returns null.
  Set<String>? findUniqueSectionOfOther(String other) {
    final o = SearchQueryAnalysis(other).tokens;
    return o.intersection(tokens).length == tokens.length
        ? o.difference(tokens)
        : null;
  }

  /// If [other] is completely contained in this, retrieves the parts of this not in other. Else returns null.
  Set<String>? findUniqueSection(String other) {
    final o = SearchQueryAnalysis(other).tokens;
    return tokens.intersection(o).length == o.length
        ? tokens.difference(o)
        : null;
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
    return other.tokens.first.contains(RegExp(curr.tokens.join("|")));
  } else {
    for (final token in other.tokens) {
      if (token.contains(RegExp(curr.tokens.join("|")))) {
        return true;
      }
    }
    return false;
  }
}

/// TODO: Complete
/* class SearchQueryMatchData {
  final String query;
  final String other;
  final String formattedQuery;
  final String formattedOther;
  final Set<String> queryTokens;
  final Set<String> otherTokens;
  // final int indexOfMatchInQuery;
  // final int indexOfMatchInOther;
  // final int lengthOfMatch;
  final Set<String> matchingTokens;

  const SearchQueryMatchData({
    required this.query,
    required this.other,
    required this.formattedQuery,
    required this.formattedOther,
    required this.queryTokens,
    required this.otherTokens,
    // required this.indexOfMatchInQuery,
    // required this.indexOfMatchInOther,
    // required this.lengthOfMatch,
    required this.matchingTokens,
  });

  /// [matchPartialSearch] - Match even if part of [query] doesn't match [potentialMatch]?
  /// [matchPartialPotential] - Match even if part of [potentialMatch] doesn't match [query]?
  static SearchQueryMatchData? findMatch(
    final String query,
    final String potentialMatch, {
    final bool matchPartialSearch = true,
    final bool matchPartialPotential = true,
    final bool matchEmptySearch = true,
    final bool matchEmptyPotential = true,
  }) {
    if (!isPotentialMatch(
      query,
      potentialMatch,
      matchEmptyPotential: matchEmptyPotential,
      matchEmptySearch: matchEmptySearch,
    )) return null;

    final curr = SearchQueryAnalysis(query.trim()),
        other = SearchQueryAnalysis(potentialMatch.trim());
    if (setEquals(curr.tokens, other.tokens)) {
      return SearchQueryMatchData(
        query: query,
        other: potentialMatch,
        formattedQuery: curr.formattedQuery,
        formattedOther: other.formattedQuery,
        queryTokens: curr.tokens,
        otherTokens: other.tokens,
        // indexOfMatchInQuery: indexOfMatchInQuery,
        // indexOfMatchInOther: indexOfMatchInOther,
        // lengthOfMatch: lengthOfMatch,
        matchingTokens: curr.tokens.toSet(),
      );
    }
    final matchingTokens = curr.tokens.intersection(other.tokens);
    if (matchingTokens.isEmpty ||
        matchingTokens.length != curr.tokens.length && !matchPartialSearch ||
        matchingTokens.length != other.tokens.length && !matchPartialSearch) {
      return null;
    } else if (matchPartialSearch &&
        matchPartialPotential &&
        matchingTokens.isNotEmpty) {
      return SearchQueryMatchData(
        query: query,
        other: potentialMatch,
        formattedQuery: curr.formattedQuery,
        formattedOther: other.formattedQuery,
        queryTokens: curr.tokens,
        otherTokens: other.tokens,
        // indexOfMatchInQuery: indexOfMatchInQuery,
        // indexOfMatchInOther: indexOfMatchInOther,
        // lengthOfMatch: lengthOfMatch,
        matchingTokens: matchingTokens,
      );
    } else if (matchPartialSearch &&
        matchPartialPotential &&
        matchingTokens.isNotEmpty) {
      return SearchQueryMatchData(
        query: query,
        other: potentialMatch,
        formattedQuery: curr.formattedQuery,
        formattedOther: other.formattedQuery,
        queryTokens: curr.tokens,
        otherTokens: other.tokens,
        // indexOfMatchInQuery: indexOfMatchInQuery,
        // indexOfMatchInOther: indexOfMatchInOther,
        // lengthOfMatch: lengthOfMatch,
        matchingTokens: matchingTokens,
      );
    }
  }
}
 */