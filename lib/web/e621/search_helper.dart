// https://e621.net/help/cheatsheet
import 'package:flutter/material.dart';
import 'package:fuzzy/map_notifier.dart';

mixin SearchableEnum /* <T extends SearchableEnum<T>> */ on Enum {
  String get searchString;
  // T? _retrieve(String str);
  // (Modifier, T)? _retrieveWithModifier(String str);
  // Iterable<(Modifier, T)>? _retrieveAllWithModifier(String str);
}

mixin SearchableStatefulEnum<T> on Enum {
  String toSearch(T state);
}

enum Order with SearchableEnum /* <Order> */ {
  /// Oldest to newest
  id("id"),

  /// Orders posts randomly *
  random("random"),

  /// Highest score first
  score("score"),

  /// Lowest score first
  scoreAsc("score_asc"),

  /// Most favorites first
  favCount("favcount"),

  /// Least favorites first
  favCountAsc("favcount_asc"),

  /// Most tags first
  tagCount("tagcount"),

  /// Least tags first
  tagCountAsc("tagcount_asc"),

  /// Most comments first
  commentCount("comment_count"),

  /// Least comments first
  commentCountAsc("comment_count_asc"),

  /// Posts with the newest comments
  commentBumped("comment_bumped"),

  /// Posts that have not been commented on for the longest time
  commentBumpedAsc("comment_bumped_asc"),

  /// Largest resolution first
  mPixels("mpixels"),

  /// Smallest resolution first
  mPixelsAsc("mpixels_asc"),

  /// Largest file size first
  fileSize("filesize"),

  /// Smallest file size first
  fileSizeAsc("filesize_asc"),

  /// Wide and short to tall and thin
  landscape("landscape"),

  /// Tall and thin to wide and short
  portrait("portrait"),

  /// Sorts by last update sequence
  change("change"),

  /// Video duration longest to shortest
  duration("duration"),

  /// Video duration shortest to longest
  durationAsc("duration_asc"),
  ;

  // static const scoreAscending = scoreAsc;
  // static const favCountAscending = favCountAsc;
  // static const tagCountAscending = tagCountAsc;
  // static const commentCountAscending = commentCountAsc;
  // static const commentBumpedAscending = commentBumpedAsc;
  // static const mPixelsAscending = mPixelsAsc;
  // static const fileSizeAscending = fileSizeAsc;
  // static const durationAscending = durationAsc;
  static const matcherNonStrictStr = "($prefix)([^\\s]+)";
  static const matcherStr = "($prefix)(id|random|score|score_asc|"
      "favcount|favcount_asc|tagcount|tagcount_asc|comment_count|"
      "comment_count_asc|comment_bumped|comment_bumped_asc|mpixels|"
      "mpixels_asc|filesize|filesize_asc|landscape|portrait|change|"
      r"duration|duration_asc)(?=\s|$)";
  static RegExp get matcherGenerated => RegExp(matcherStr);
  static const prefix = "order:";
  final String tagSuffix;

  @override
  String get searchString => "$prefix$tagSuffix";

  const Order(this.tagSuffix);
  factory Order.fromTagText(String tagText) =>
      switch (tagText.replaceAll(("$prefix|${r"\s"}"), "")) {
        "id" => id,
        "random" => random,
        "score" => score,
        "score_asc" => scoreAsc,
        "favcount" => favCount,
        "favcount_asc" => favCountAsc,
        "tagcount" => tagCount,
        "tagcount_asc" => tagCountAsc,
        "comment_count" => commentCount,
        "comment_count_asc" => commentCountAsc,
        "comment_bumped" => commentBumped,
        "comment_bumped_asc" => commentBumpedAsc,
        "mpixels" => mPixels,
        "mpixels_asc" => mPixelsAsc,
        "filesize" => fileSize,
        "filesize_asc" => fileSizeAsc,
        "landscape" => landscape,
        "portrait" => portrait,
        "change" => change,
        "duration" => duration,
        "duration_asc" => durationAsc,
        _ => throw ArgumentError.value(tagText, "tagText", "Value not of type"),
      };
  factory Order.fromText(String text) =>
      switch (text.replaceAll(("$prefix|${r"\s"}"), "")) {
        "id" => id,
        String t when t == id.name => id,
        "random" => random,
        String t when t == random.name => random,
        "score" => score,
        String t when t == score.name => score,
        "score_asc" => scoreAsc,
        String t when t == scoreAsc.name => scoreAsc,
        "favcount" => favCount,
        String t when t == favCount.name => favCount,
        "favcount_asc" => favCountAsc,
        String t when t == favCountAsc.name => favCountAsc,
        "tagcount" => tagCount,
        String t when t == tagCount.name => tagCount,
        "tagcount_asc" => tagCountAsc,
        String t when t == tagCountAsc.name => tagCountAsc,
        "comment_count" => commentCount,
        String t when t == commentCount.name => commentCount,
        "comment_count_asc" => commentCountAsc,
        String t when t == commentCountAsc.name => commentCountAsc,
        "comment_bumped" => commentBumped,
        String t when t == commentBumped.name => commentBumped,
        "comment_bumped_asc" => commentBumpedAsc,
        String t when t == commentBumpedAsc.name => commentBumpedAsc,
        "mpixels" => mPixels,
        String t when t == mPixels.name => mPixels,
        "mpixels_asc" => mPixelsAsc,
        String t when t == mPixelsAsc.name => mPixelsAsc,
        "filesize" => fileSize,
        String t when t == fileSize.name => fileSize,
        "filesize_asc" => fileSizeAsc,
        String t when t == fileSizeAsc.name => fileSizeAsc,
        "landscape" => landscape,
        String t when t == landscape.name => landscape,
        "portrait" => portrait,
        String t when t == portrait.name => portrait,
        "change" => change,
        String t when t == change.name => change,
        "duration" => duration,
        String t when t == duration.name => duration,
        "duration_asc" => durationAsc,
        String t when t == durationAsc.name => durationAsc,
        _ => throw ArgumentError.value(text, "text", "Value not of type"),
      };
  static Order? retrieve(String str) {
    try {
      return Order.fromTagText(
          Order.matcherGenerated.firstMatch(str)!.group(2)!);
    } catch (e) {
      return null;
    }
  }

  static (Modifier, Order)? retrieveWithModifier(String str) {
    final v = retrieve(str);
    return v == null ? null : (Modifier.add, v);
  }

  static Iterable<(Modifier, Order)>? retrieveAllWithModifier(String str) {
    try {
      return Order.matcherGenerated
          .allMatches(str)
          .map((e) => (Modifier.add, Order.fromTagText(e.group(2)!)));
    } catch (e) {
      return null;
    }
  }

  // @override
  // Order? _retrieve(String str) => retrieve(str);
  // @override
  // (Modifier, Order)? _retrieveWithModifier(String str) =>
  //     retrieveWithModifier(str);
  // @override
  // Iterable<(Modifier, Order)>? _retrieveAllWithModifier(String str) =>
  //     retrieveAllWithModifier(str);
}

const prefixModifierMatcher = r"[\-\~\+]?";

enum Rating with SearchableEnum /* <Rating> */ {
  safe,
  questionable,
  explicit;

  static const matcherNonStrictStr =
      "($prefixModifierMatcher)($prefix)([^\\s]+)";
  static RegExp get matcherNonStrictGenerated => RegExp(matcherNonStrictStr);
  static const matcherStr = "($prefixModifierMatcher)($prefix)"
      r"(s|q|e|safe|questionable|explicit)(?=\s|$)";
  static RegExp get matcherGenerated => RegExp(matcherStr);
  static const prefix = "rating:";
  @override
  String get searchString => searchStringShort;
  String get searchStringShort => "$prefix${name[0]}";
  String get searchStringLong => "$prefix$name";
  String get suffix => suffixShort;
  String get suffixShort => name[0];
  String get suffixLong => name;
  const Rating();
  factory Rating.fromTagText(String str) => switch (str) {
        "e" => explicit,
        "explicit" => explicit,
        "q" => questionable,
        "questionable" => questionable,
        "s" => safe,
        "safe" => safe,
        _ => throw UnsupportedError("type not supported"),
      };
  factory Rating.fromText(String str) => switch (str) {
        "$prefix:e" => explicit,
        "$prefix:explicit" => explicit,
        "$prefix:q" => questionable,
        "$prefix:questionable" => questionable,
        "$prefix:s" => safe,
        "$prefix:safe" => safe,
        _ => Rating.fromTagText(str),
      };

  // @override
  // Rating? _retrieve(String str) => retrieve(str);
  static Rating? retrieve(String str) {
    if (!Rating.matcherGenerated.hasMatch(str)) {
      return null;
    }
    return Rating.fromTagText(matcherGenerated.firstMatch(str)!.group(3)!);
  }

  // @override
  // (Modifier, Rating)? _retrieveWithModifier(String str) =>
  //     retrieveWithModifier(str);
  static (Modifier, Rating)? retrieveWithModifier(String str) {
    if (!Rating.matcherGenerated.hasMatch(str)) {
      return null;
    }
    final ms = Rating.matcherGenerated.allMatches(str);
    final tags = ms.fold(
      <(Modifier, Rating)>{},
      (previousValue, e) => previousValue
        ..add(
          (
            Modifier.fromString(e.group(1) ?? ""),
            Rating.fromTagText(e.group(2)!)
          ),
        ),
    );
    (Modifier, Rating)? r;
    for (final t in tags) {
      if (r == null) {
        r = t;
      } else {
        if (r.$1 == Modifier.add) {
          if (t.$1 == Modifier.remove && t.$2 == r.$2) {
            return null;
          } else if (t.$1 == Modifier.add && t.$2 != r.$2) {
            return null;
          } else if (t.$1 == Modifier.or) {
            continue;
            //return null;
          } /*  else if (t.$1 == Modifier.remove && t.$2 != r.$2) {
            continue;
          } */
        } else if (r.$1 == Modifier.remove) {
          if (t.$1 == Modifier.add && t.$2 == r.$2) {
            return null;
          } else if (t.$1 == Modifier.remove && t.$2 != r.$2) {
            r = (
              Modifier.add,
              switch ((r.$2, t.$2)) {
                (safe, questionable) => explicit,
                (questionable, safe) => explicit,
                (safe, explicit) => questionable,
                (explicit, safe) => questionable,
                (questionable, explicit) => safe,
                (explicit, questionable) => safe,
                (safe, safe) => throw StateError("Should be impossible"),
                (questionable, questionable) =>
                  throw StateError("Should be impossible"),
                (explicit, explicit) =>
                  throw StateError("Should be impossible"),
              }
            );
          } else if (t.$1 == Modifier.or && t.$2 == r.$2) {
            return null;
          }
        } else if (r.$1 == Modifier.or) {
          if (t.$1 == Modifier.add && t.$2 != r.$2) {
            return null;
          } else if (t.$1 == Modifier.or && t.$2 != r.$2) {
            r = (
              Modifier.remove,
              switch ((r.$2, t.$2)) {
                (safe, questionable) => explicit,
                (questionable, safe) => explicit,
                (safe, explicit) => questionable,
                (explicit, safe) => questionable,
                (questionable, explicit) => safe,
                (explicit, questionable) => safe,
                (safe, safe) => throw StateError("Should be impossible"),
                (questionable, questionable) =>
                  throw StateError("Should be impossible"),
                (explicit, explicit) =>
                  throw StateError("Should be impossible"),
              }
            );
          } else if (t.$1 == Modifier.remove && t.$2 != r.$2) {
            r = t;
          } else if (t.$1 == Modifier.remove && t.$2 == r.$2) {
            r = (Modifier.remove, r.$2);
          }
        }
      }
    }
    return r;
  }
}

enum Modifier {
  add,
  remove,
  or;

  const Modifier();
  factory Modifier.fromString(String s) => switch (s) {
        "+" || "" => Modifier.add,
        "-" => Modifier.remove,
        "~" => Modifier.or,
        _ => throw UnsupportedError("type not supported"),
      };
  String get symbol => symbolSlim;
  String get symbolFull => switch (this) {
        Modifier.add => "+",
        Modifier.remove => "-",
        Modifier.or => "~",
      };
  String get symbolSlim => switch (this) {
        Modifier.add => "",
        Modifier.remove => "-",
        Modifier.or => "~",
      };
  static const dropdownItems = <DropdownMenuItem<Modifier>>[
    DropdownMenuItem(value: Modifier.add, child: Text("+")),
    DropdownMenuItem(value: Modifier.remove, child: Text("-")),
    DropdownMenuItem(value: Modifier.or, child: Text("~")),
  ];
  static const dropdownItemsFull = <DropdownMenuItem<Modifier?>>[
    DropdownMenuItem(value: Modifier.add, child: Text("+")),
    DropdownMenuItem(value: Modifier.remove, child: Text("-")),
    DropdownMenuItem(value: Modifier.or, child: Text("~")),
    DropdownMenuItem(value: null, child: Icon(Icons.close)),
  ];
  static const dropdownEntries = <DropdownMenuEntry<Modifier>>[
    DropdownMenuEntry(value: Modifier.add, label: "+"),
    DropdownMenuEntry(value: Modifier.remove, label: "-"),
    DropdownMenuEntry(value: Modifier.or, label: "~"),
  ];
  static const dropdownEntriesFull = <DropdownMenuEntry<Modifier?>>[
    DropdownMenuEntry(
      value: Modifier.add,
      label: "+",
      labelWidget: SizedBox(
        width: 12,
        child: Text(
          "+",
          textWidthBasis: TextWidthBasis.parent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
    DropdownMenuEntry(
      value: Modifier.remove,
      label: "-",
      labelWidget: SizedBox(
        width: 12,
        child: Text(
          "-",
          textWidthBasis: TextWidthBasis.parent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
    DropdownMenuEntry(
      value: Modifier.or,
      label: "~",
      labelWidget: SizedBox(
        width: 12,
        child: Text(
          "~",
          textWidthBasis: TextWidthBasis.parent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
    DropdownMenuEntry(
      value: null,
      label: "X",
      labelWidget: SizedBox(
        width: 12,
        child: Text(
          "X",
          textWidthBasis: TextWidthBasis.parent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  ];
}

enum FileType with SearchableEnum {
  jpg,
  png,
  gif,
  swf,
  webm;

  static const matcherNonStrictStr =
      "($prefixModifierMatcher)($prefixFull)" r"([^\s]+)";
  static final matcherNonStrict = RegExp(matcherNonStrictStr);
  static RegExp get matcherNonStrictGenerated => RegExp(matcherNonStrictStr);
  static const matcherStr = "($prefixModifierMatcher)"
      "($prefixFull)"
      r"(jpg|png|gif|swf|webm)(?=\s|$)";
  static final matcher = RegExp(matcherStr);
  static RegExp get matcherGenerated => RegExp(matcherStr);
  static const prefixFull = "type:";
  static const prefix = "type";
  @override
  String get searchString => "$prefixFull$name";
  String get suffix => name;
  factory FileType.fromTagText(String str) => switch (str) {
        "jpeg" => jpg,
        "jpg" => jpg,
        "png" => png,
        "gif" => gif,
        "swf" => swf,
        "webm" => webm,
        _ => throw UnsupportedError("type not supported"),
      };
  factory FileType.fromText(String str) => switch (str) {
        "${prefixFull}jpeg" => jpg,
        "${prefixFull}jpg" => jpg,
        "${prefixFull}png" => png,
        "${prefixFull}gif" => gif,
        "${prefixFull}swf" => swf,
        "${prefixFull}webm" => webm,
        _ => FileType.fromTagText(str),
      };

  static List<(Modifier, FileType)>? retrieveAllWithModifier(String str) {
    if (!FileType.matcherGenerated.hasMatch(str)) {
      return null;
    }
    final ms = FileType.matcherGenerated.allMatches(str);
    final tags = ms.fold(
      <(Modifier, FileType)>{},
      (previousValue, e) => previousValue
        ..add(
          (
            Modifier.fromString(e.group(1) ?? ""),
            FileType.fromTagText(e.group(2)!)
          ),
        ),
    );
    return tags.toList();
  }
}

enum BooleanSearchTag with SearchableStatefulEnum<bool> {
  isChild("ischild"),
  isParent("isparent"),
  hasSource("hassource"),
  hasDescription("hasdescription"),
  ratingLocked("ratinglocked"),
  noteLocked("notelocked"),
  inPool("inpool"),
  pendingReplacements("pending_replacements");

  final String tagPrefix;
  const BooleanSearchTag(this.tagPrefix);
  factory BooleanSearchTag.fromTagText(String str) => switch (str) {
        "ischild" => isChild,
        "isparent" => isParent,
        "hassource" => hasSource,
        "hasdescription" => hasDescription,
        "ratinglocked" => ratingLocked,
        "notelocked" => noteLocked,
        "inpool" => inPool,
        "pending_replacements" => pendingReplacements,
        _ => throw UnsupportedError("type not supported"),
      };
  factory BooleanSearchTag.fromText(String str) => switch (str) {
        "ischild:true" => isChild,
        "ischild:false" => isChild,
        "isparent:true" => isParent,
        "isparent:false" => isParent,
        "hassource:true" => hasSource,
        "hassource:false" => hasSource,
        "hasdescription:true" => hasDescription,
        "hasdescription:false" => hasDescription,
        "ratinglocked:true" => ratingLocked,
        "ratinglocked:false" => ratingLocked,
        "notelocked:true" => noteLocked,
        "notelocked:false" => noteLocked,
        "inpool:true" => inPool,
        "inpool:false" => inPool,
        "pending_replacements:true" => pendingReplacements,
        "pending_replacements:false" => pendingReplacements,
        _ => BooleanSearchTag.fromTagText(str),
      };
  String toSearchTagNullable(bool? value) =>
      value == null ? "" : "$tagPrefix:$value";
  @override
  String toSearch(bool state) => "$tagPrefix:$state";

  static const String matcherStr = "($prefixModifierMatcher)"
      r"(ischild|isparent|hassource|hasdescription|ratinglocked|notelocked|inpool|pending_replacements):(true|false)";
  static RegExp get matcher => RegExp(matcherStr);
  // static List<(Modifier, (BooleanSearchTag, bool))>? retrieveAllWithModifier(
  //     String str) {
  //   if (!BooleanSearchTag.matcher.hasMatch(str)) {
  //     return null;
  //   }
  //   validate(Set<(Modifier, (BooleanSearchTag, bool))> set,
  //       (Modifier, (BooleanSearchTag, bool)) e) {
  //     final prior =
  //         set.firstWhere((element) => element.$1 == e.$1, orElse: () => e);
  //     return switch (prior) {
  //       (Modifier m, (_, bool b)) when m == e.$1 && b == e.$2.$2 => set
  //         ..remove(prior)
  //         ..add(e),
  //       (Modifier m, (_, bool b)) when m == e.$1 && b != e.$2.$2 => set..remove(prior),
  //       (Modifier m, (_, bool b)) when m != e.$1 && b == e.$2.$2 => switch ((m,b,e.$1)) {
  //         (Modifier.or, _, Modifier.add) || (Modifier.or, _, Modifier.remove) => set..remove(prior)..add(e),
  //         (Modifier.add, _, Modifier.or) || (Modifier.remove, _, Modifier.or) => set,
  //         (Modifier p1, bool p2,Modifier c) when p1 == Modifier.or =>set..remove(prior)..add(e),
  //         _ => throw UnsupportedError("type not supported"),
  //       },
  //       (Modifier m, (_, bool b)) when m != e.$1 && b == e.$2.$2 => switch ((m,b,e.$1,e.$2.$2)) {
  //         (Modifier p1, bool p2,Modifier c1,bool c2) when p1 == Modifier.or =>set..remove(prior),
  //         _ => throw UnsupportedError("type not supported"),
  //       },
  //     };
  //   }

  //   final ms = BooleanSearchTag.matcher.allMatches(str);
  //   final tags = ms.fold(
  //       <(Modifier, (BooleanSearchTag, bool))>{},
  //       (previousValue, e) =>
  //           validate(previousValue, retrieveWithModifier(e.group(0)!))
  //       // previousValue..add(retrieveWithModifier(e.group(0)!)),
  //       );
  //   return tags.toList();
  // }

  static List<(BooleanSearchTag, bool)>? retrieveAll(String str) {
    if (!BooleanSearchTag.matcher.hasMatch(str)) {
      return null;
    }
    validate(Set<(BooleanSearchTag, bool)> set, (BooleanSearchTag, bool) e) {
      final prior =
          set.firstWhere((element) => element.$1 == e.$1, orElse: () => e);
      return switch (prior.$2) {
        bool t when t == e.$2 => set
          ..remove(prior)
          ..add(e),
        bool t when t != e.$2 => set..remove(prior),
        true || false => throw UnimplementedError(),
      };
    }

    final ms = BooleanSearchTag.matcher.allMatches(str);
    final tags = ms.fold(
        <(BooleanSearchTag, bool)>{},
        (previousValue, e) =>
            validate(previousValue, parseSearchFragment(e.group(0)!))
        // previousValue..add(parseSearchFragment(e.group(0)!)),
        );
    return tags.toList();
  }

  static (Modifier, (BooleanSearchTag, bool))? retrieveWithModifier(
      String str) {
    final m = BooleanSearchTag.matcher.firstMatch(str);
    return m == null
        ? null
        : (
            Modifier.fromString(m.group(1)!),
            (BooleanSearchTag.fromTagText(m.group(2)!), bool.parse(m.group(3)!))
          );
  }

  static (BooleanSearchTag, bool)? tryParseSearchFragment(String str) {
    final m = BooleanSearchTag.matcher.firstMatch(str);
    return m == null
        ? null
        : (
            BooleanSearchTag.fromTagText(m.group(2)!),
            Modifier.fromString(m.group(1)!) != Modifier.remove
                ? bool.parse(m.group(3)!)
                : !bool.parse(m.group(3)!)
          );
  }

  static (BooleanSearchTag, bool) parseSearchFragment(String str) =>
      tryParseSearchFragment(str)!;
}

enum Status with SearchableEnum {
  pending,
  active,
  deleted,
  flagged,
  modqueue,
  any;

  static const prefix = "status";
  static const prefixFull = "status:";
  static const String matcherStr = "($prefixModifierMatcher)$prefixFull"
      r"(pending|active|deleted|flagged|modqueue|any)(?=\s|$)";
  static RegExp get matcher => RegExp(matcherStr);

  @override
  String get searchString => "$prefixFull$name";
  factory Status.fromTagText(String str) => switch (str) {
        "pending" => pending,
        "active" => active,
        "deleted" => deleted,
        "flagged" => flagged,
        "modqueue" => modqueue,
        "any" => any,
        _ => throw UnsupportedError("type not supported"),
      };
  factory Status.fromText(String str) => switch (str) {
        "${prefixFull}pending" => pending,
        "${prefixFull}active" => active,
        "${prefixFull}deleted" => deleted,
        "${prefixFull}flagged" => flagged,
        "${prefixFull}modqueue" => modqueue,
        "${prefixFull}any" => any,
        _ => Status.fromTagText(str),
      };

  static List<(Modifier, Status)>? retrieveAllWithModifier(String str) {
    if (!Status.matcher.hasMatch(str)) {
      return null;
    }
    final ms = Status.matcher.allMatches(str);
    final tags = ms.fold(
      <(Modifier, Status)>{},
      (previousValue, e) => previousValue
        ..add(
          (
            Modifier.fromString(e.group(1) ?? ""),
            Status.fromTagText(e.group(2)!)
          ),
        ),
    );
    return tags.toList();
  }
}

class MetaTagSearchData extends ChangeNotifier {
  static const defaultRating = Rating.safe;
  bool? _addRating;

  /// Tristate; true for additive (""/"+"), false for subtractive ("-"), null to exclude;
  bool? get addRating => _addRating;

  /// Tristate; true for additive (""/"+"), false for subtractive ("-"), null to exclude;
  set addRating(bool? value) {
    _addRating = value;
    notifyListeners();
  }

  Rating _rating;
  Rating get rating => _rating;
  set rating(Rating value) {
    _rating = value;
    notifyListeners();
  }

  Order? _order;
  Order? get order => _order;
  set order(Order? value) {
    _order = value;
    notifyListeners();
  }

  MapNotifier<FileType, Modifier> _types;
  Map<FileType, Modifier> get types => _types;
  set types(Map<FileType, Modifier> value) {
    // _types..removeListener(_listener)..dispose();
    _types.removeListener(_listener);
    _types = MapNotifier.of(value)..addListener(_listener);
    notifyListeners();
  }

  MapNotifier<Status, Modifier> _status;
  Map<Status, Modifier> get status => _status;
  set status(Map<Status, Modifier> value) {
    // _status..removeListener(_listener)..dispose();
    _status.removeListener(_listener);
    _status = MapNotifier.of(value)..addListener(_listener);
    notifyListeners();
  }

  bool? _isChild;
  bool? get isChild => _isChild;
  set isChild(bool? value) {
    _isChild = value;
    notifyListeners();
  }

  bool? _isParent;
  bool? get isParent => _isParent;
  set isParent(bool? value) {
    _isParent = value;
    notifyListeners();
  }

  bool? _pendingReplacements;
  bool? get pendingReplacements => _pendingReplacements;
  set pendingReplacements(bool? value) {
    _pendingReplacements = value;
    notifyListeners();
  }

  bool? _hasSource;
  bool? get hasSource => _hasSource;
  set hasSource(bool? value) {
    _hasSource = value;
    notifyListeners();
  }

  bool? _hasDescription;
  bool? get hasDescription => _hasDescription;
  set hasDescription(bool? value) {
    _hasDescription = value;
    notifyListeners();
  }

  bool? _ratingLocked;
  bool? get ratingLocked => _ratingLocked;
  set ratingLocked(bool? value) {
    _ratingLocked = value;
    notifyListeners();
  }

  bool? _noteLocked;
  bool? get noteLocked => _noteLocked;
  set noteLocked(bool? value) {
    _noteLocked = value;
    notifyListeners();
  }

  bool? _inPool;
  bool? get inPool => _inPool;
  set inPool(bool? value) {
    _inPool = value;
    notifyListeners();
  }

  MetaTagSearchData({
    Order? order,
    bool? addRating,
    Rating rating = defaultRating,
    bool? isChild,
    bool? isParent,
    bool? pendingReplacements,
    bool? hasSource,
    bool? hasDescription,
    bool? ratingLocked,
    bool? noteLocked,
    bool? inPool,
    Map<FileType, Modifier>? types,
    Map<Status, Modifier>? status,
  })  : _addRating = addRating,
        _rating = rating,
        _order = order,
        _isChild = isChild,
        _isParent = isParent,
        _pendingReplacements = pendingReplacements,
        _hasSource = hasSource,
        _hasDescription = hasDescription,
        _ratingLocked = ratingLocked,
        _noteLocked = noteLocked,
        _inPool = inPool,
        _types = types is MapNotifier<FileType, Modifier>
            ? types
            : MapNotifier<FileType, Modifier>.of(types ?? {}),
        _status = status is MapNotifier<Status, Modifier>
            ? status
            : MapNotifier<Status, Modifier>.of(status ?? {}) {
    _types.addListener(_listener);
    _status.addListener(_listener);
  }
  MetaTagSearchData.req({
    required Order? order,
    required bool? addRating,
    required Rating rating,
    required bool? isChild,
    required bool? isParent,
    required bool? pendingReplacements,
    required bool? hasSource,
    required bool? hasDescription,
    required bool? ratingLocked,
    required bool? noteLocked,
    required bool? inPool,
    required Map<FileType, Modifier> types,
    required Map<Status, Modifier> status,
  })  : _addRating = addRating,
        _rating = rating,
        _order = order,
        _types = types is MapNotifier<FileType, Modifier>
            ? types
            : MapNotifier<FileType, Modifier>.from(types),
        _status = status is MapNotifier<Status, Modifier>
            ? status
            : MapNotifier<Status, Modifier>.from(status),
        _isChild = isChild,
        _isParent = isParent,
        _pendingReplacements = pendingReplacements,
        _hasSource = hasSource,
        _hasDescription = hasDescription,
        _ratingLocked = ratingLocked,
        _noteLocked = noteLocked,
        _inPool = inPool {
    _types.addListener(_listener);
    _status.addListener(_listener);
  }
  void _listener() => notifyListeners();

  factory MetaTagSearchData.fromSearchString(String str) {
    if (str.isEmpty) return MetaTagSearchData();
    final r = Rating.retrieveWithModifier(str);
    final b = BooleanSearchTag.retrieveAll(str);
    bool? isChild,
        isParent,
        pendingReplacements,
        hasSource,
        hasDescription,
        ratingLocked,
        noteLocked,
        inPool;
    for (final e in b ?? const <(BooleanSearchTag, bool)>[]) {
      switch (e.$1) {
        case BooleanSearchTag.isChild:
          isChild = e.$2;
          break;
        case BooleanSearchTag.isParent:
          isParent = e.$2;
          break;
        case BooleanSearchTag.inPool:
          inPool = e.$2;
          break;
        case BooleanSearchTag.hasDescription:
          hasDescription = e.$2;
          break;
        case BooleanSearchTag.hasSource:
          hasSource = e.$2;
          break;
        case BooleanSearchTag.noteLocked:
          noteLocked = e.$2;
          break;
        case BooleanSearchTag.pendingReplacements:
          pendingReplacements = e.$2;
          break;
        case BooleanSearchTag.ratingLocked:
          ratingLocked = e.$2;
          break;
      }
    }
    return MetaTagSearchData.req(
      order: Order.retrieve(str),
      addRating: r?.$1 == Modifier.add
          ? true
          : r?.$1 == Modifier.remove
              ? false
              : null,
      rating: Rating.retrieveWithModifier(str)?.$2 ?? defaultRating,
      isChild: isChild,
      isParent: isParent,
      pendingReplacements: pendingReplacements,
      hasSource: hasSource,
      hasDescription: hasDescription,
      ratingLocked: ratingLocked,
      noteLocked: noteLocked,
      inPool: inPool,
      status: Status.retrieveAllWithModifier(str)
              ?.fold<Map<Status, Modifier>>({}, (prior, e) {
            prior[e.$2] = e.$1;
            return prior;
          }) ??
          {},
      types: FileType.retrieveAllWithModifier(str)
              ?.fold<Map<FileType, Modifier>>({}, (prior, e) {
            prior[e.$2] = e.$1;
            return prior;
          }) ??
          {},
    );
  }
  bool? getBooleanParameter(BooleanSearchTag t) => switch (t) {
        BooleanSearchTag.isChild => isChild,
        BooleanSearchTag.isParent => isParent,
        BooleanSearchTag.hasSource => hasSource,
        BooleanSearchTag.hasDescription => hasDescription,
        BooleanSearchTag.ratingLocked => ratingLocked,
        BooleanSearchTag.noteLocked => noteLocked,
        BooleanSearchTag.inPool => inPool,
        BooleanSearchTag.pendingReplacements => pendingReplacements,
      };
  bool? setBooleanParameter(BooleanSearchTag t, bool? value) => switch (t) {
        BooleanSearchTag.isChild => isChild = value,
        BooleanSearchTag.isParent => isParent = value,
        BooleanSearchTag.hasSource => hasSource = value,
        BooleanSearchTag.hasDescription => hasDescription = value,
        BooleanSearchTag.ratingLocked => ratingLocked = value,
        BooleanSearchTag.noteLocked => noteLocked = value,
        BooleanSearchTag.inPool => inPool = value,
        BooleanSearchTag.pendingReplacements => pendingReplacements = value
      };

  void clear() {
    _addRating = null;
    _order = null;
    _types
      ..removeListener(_listener)
      ..clear()
      ..addListener(_listener);
    _status
      ..removeListener(_listener)
      ..clear()
      ..addListener(_listener);
    _isChild = null;
    _isParent = null;
    _pendingReplacements = null;
    _hasSource = null;
    _hasDescription = null;
    _ratingLocked = null;
    _noteLocked = null;
    _inPool = null;

    notifyListeners();
  }

  /// The same as [clear] but also resetting [ratings] to [defaultRating].
  void reset() {
    _rating = defaultRating;
    clear();
  }

  // #region toString Properties
  String get typeString => types.keys.fold(
      "",
      (p, e) => "$p "
          "${(types[e] ?? Modifier.add).symbolSlim}"
          "${e.searchString}");

  String get statusString => status.keys.fold(
      "",
      (p, e) => "$p "
          "${(status[e] ?? Modifier.add).symbolSlim}"
          "${e.searchString}");
  String get orderString => order != null ? " ${order!.searchString}" : "";
  String get ratingString => addRating != null
      ? " ${addRating! ? "" : "-"}${rating.searchString}"
      : "";
  String get isChildString =>
      isChild == null ? "" : " ${BooleanSearchTag.isChild.toSearch(isChild!)}";
  String get isParentString => isParent == null
      ? ""
      : " ${BooleanSearchTag.isParent.toSearch(isParent!)}";
  String get pendingReplacementsString => pendingReplacements == null
      ? ""
      : " ${BooleanSearchTag.pendingReplacements.toSearch(pendingReplacements!)}";
  String get hasSourceString => hasSource == null
      ? ""
      : " ${BooleanSearchTag.hasSource.toSearch(hasSource!)}";
  String get hasDescriptionString => hasDescription == null
      ? ""
      : " ${BooleanSearchTag.hasDescription.toSearch(hasDescription!)}";
  String get ratingLockedString => ratingLocked == null
      ? ""
      : " ${BooleanSearchTag.ratingLocked.toSearch(ratingLocked!)}";
  String get noteLockedString => noteLocked == null
      ? ""
      : " ${BooleanSearchTag.noteLocked.toSearch(noteLocked!)}";
  String get inPoolString =>
      inPool == null ? "" : " ${BooleanSearchTag.inPool.toSearch(inPool!)}";
  // #endregion toString Properties

  @override
  String toString() =>
      orderString +
      ratingString +
      typeString +
      statusString +
      isChildString +
      isParentString +
      pendingReplacementsString +
      hasSourceString +
      hasDescriptionString +
      ratingLockedString +
      noteLockedString +
      inPoolString;
  String removeMatchedMetaTags(String str) {
    return str.replaceAll(
        RegExp("($orderString)|"
            "($ratingString)|"
            "($typeString)|"
            "($statusString)|"
            "($isChildString)|"
            "($isParentString)|"
            "($pendingReplacementsString)|"
            "($hasSourceString)|"
            "($hasDescriptionString)|"
            "($ratingLockedString)|"
            "($noteLockedString)|"
            "($inPoolString)"),
        "");
    // .replaceAll(RegExp(r"\s{2,}"), " ");
  }
}

String removeMetaTags(String str) {
  return str
      .replaceAll(
          RegExp("(${Rating.matcherStr})|"
              "(${BooleanSearchTag.matcherStr})|"
              "(${Order.matcherStr})|"
              "(${Status.matcherStr})|"
              "(${FileType.matcherStr})"),
          "")
      .replaceAll(RegExp(r"\s{2,}"), " ");
}

const modifierTagCompleteListString = [
  "order:id",
  "order:random",
  "order:score",
  "order:score_asc",
  "order:favcount",
  "order:favcount_asc",
  "order:tagcount",
  "order:tagcount_asc",
  "order:comment_count",
  "order:comment_count_asc",
  "order:comment_bumped",
  "order:comment_bumped_asc",
  "order:mpixels",
  "order:mpixels_asc",
  "order:filesize",
  "order:filesize_asc",
  "order:landscape",
  "order:portrait",
  "order:change",
  "order:duration",
  "order:duration_asc",
  "voted:anything",
  "votedup:anything",
  "voteddown:anything",
  "rating:safe",
  "rating:questionable",
  "rating:explicit",
  "rating:s",
  "rating:q",
  "rating:e",
  "type:jpg",
  "type:png",
  "type:gif",
  "type:swf",
  "type:webm",
  "status:pending",
  "status:active",
  "status:deleted",
  "status:flagged",
  "status:modqueue",
  "status:any",
  "date:today",
  "date:yesterday",
  "date:day",
  "date:week",
  "date:month",
  "date:year",
  "date:decade",
  "date:yesterweek",
  "date:yestermonth",
  "date:yesteryear",
  "source:none",
  "ischild:true",
  "ischild:false",
  "isparent:true",
  "isparent:false",
  "parent:none",
  "hassource:true",
  "hassource:false",
  "hasdescription:true",
  "hasdescription:false",
  "ratinglocked:true",
  "ratinglocked:false",
  "notelocked:true",
  "notelocked:false",
  "inpool:true",
  "inpool:false",
  "pending_replacements:true",
  "pending_replacements:false",
];

const modifierTagStubListString = [
  "order:random randseed:",
  "user:",
  "user:!",
  "fav:",
  "approver:",
  "deletedby:",
  "commenter:",
  "noteupdater:",
  "id:",
  "score:",
  "favcount:",
  "comment_count:",
  "tagcount:",
  "gentags:",
  "arttags:",
  "chartags:",
  "copytags:",
  "spectags:",
  "invtags:",
  "lortags:",
  "metatags:",
  "type:",
  "width:",
  "height:",
  "mpixels:",
  "ratio:",
  "filesize:",
  "status:",
  "date:",
  "source:",
  "description:",
  "note:",
  "delreason:",
  "parent:",
  "hassource:",
  "hasdescription:",
  "ratinglocked:",
  "notelocked:",
  "inpool:",
  "pending_replacements:",
  "pool:",
  "set:",
  "md5:",
  "duration:",
];

const allModifierTagsList = [
  "order:id",
  "order:random",
  "order:score",
  "order:score_asc",
  "order:favcount",
  "order:favcount_asc",
  "order:tagcount",
  "order:tagcount_asc",
  "order:comment_count",
  "order:comment_count_asc",
  "order:comment_bumped",
  "order:comment_bumped_asc",
  "order:mpixels",
  "order:mpixels_asc",
  "order:filesize",
  "order:filesize_asc",
  "order:landscape",
  "order:portrait",
  "order:change",
  "order:duration",
  "order:duration_asc",
  "order:random randseed:",
  "voted:anything",
  "votedup:anything",
  "voteddown:anything",
  "rating:safe",
  "rating:questionable",
  "rating:explicit",
  "rating:s",
  "rating:q",
  "rating:e",
  "type:jpg",
  "type:png",
  "type:gif",
  "type:swf",
  "type:webm",
  "status:pending",
  "status:active",
  "status:deleted",
  "status:flagged",
  "status:modqueue",
  "status:any",
  "date:today",
  "date:yesterday",
  "date:day",
  "date:week",
  "date:month",
  "date:year",
  "date:decade",
  "date:yesterweek",
  "date:yestermonth",
  "date:yesteryear",
  "source:none",
  "ischild:true",
  "ischild:false",
  "isparent:true",
  "isparent:false",
  "parent:none",
  "hassource:true",
  "hassource:false",
  "hasdescription:true",
  "hasdescription:false",
  "ratinglocked:true",
  "ratinglocked:false",
  "notelocked:true",
  "notelocked:false",
  "inpool:true",
  "inpool:false",
  "pending_replacements:true",
  "pending_replacements:false",
  "user:",
  "user:!",
  "fav:",
  "approver:",
  "deletedby:",
  "commenter:",
  "noteupdater:",
  "id:",
  "score:",
  "favcount:",
  "comment_count:",
  "tagcount:",
  "gentags:",
  "arttags:",
  "chartags:",
  "copytags:",
  "spectags:",
  "invtags:",
  "lortags:",
  "metatags:",
  "type:",
  "width:",
  "height:",
  "mpixels:",
  "ratio:",
  "filesize:",
  "status:",
  "date:",
  "source:",
  "description:",
  "note:",
  "delreason:",
  "parent:",
  "hassource:",
  "hasdescription:",
  "ratinglocked:",
  "notelocked:",
  "inpool:",
  "pending_replacements:",
  "pool:",
  "set:",
  "md5:",
  "duration:",
];
const modifierTagsSuggestionsList = [
  // "order:id",
  // "order:random",
  // "order:score",
  // "order:score_asc",
  // "order:favcount",
  // "order:favcount_asc",
  // "order:tagcount",
  // "order:tagcount_asc",
  // "order:comment_count",
  // "order:comment_count_asc",
  // "order:comment_bumped",
  // "order:comment_bumped_asc",
  // "order:mpixels",
  // "order:mpixels_asc",
  // "order:filesize",
  // "order:filesize_asc",
  // "order:landscape",
  // "order:portrait",
  // "order:change",
  // "order:duration",
  // "order:duration_asc",
  // "order:random randseed:",
  "voted:anything",
  "votedup:anything",
  "voteddown:anything",
  /* "rating:s",
  "rating:q",
  "rating:e", */
  /* "type:jpg",
  "type:png",
  "type:gif",
  "type:swf",
  "type:webm", */
  /* "status:pending",
  "status:active",
  "status:deleted",
  "status:flagged",
  "status:modqueue",
  "status:any", */
  "date:today",
  "date:yesterday",
  "date:day",
  "date:week",
  "date:month",
  "date:year",
  "date:decade",
  "date:yesterweek",
  "date:yestermonth",
  "date:yesteryear",
  "source:none",
  /* "ischild:true",
  "ischild:false",
  "isparent:true",
  "isparent:false", */
  "parent:none",
  /* "hassource:true",
  "hassource:false",
  "hasdescription:true",
  "hasdescription:false",
  "ratinglocked:true",
  "ratinglocked:false",
  "notelocked:true",
  "notelocked:false",
  "inpool:true",
  "inpool:false",
  "pending_replacements:true",
  "pending_replacements:false", */
  "user:",
  "user:!",
  "fav:",
  "approver:",
  "deletedby:",
  "commenter:",
  "noteupdater:",
  "id:",
  "score:",
  "favcount:",
  "comment_count:",
  "tagcount:",
  "gentags:",
  "arttags:",
  "chartags:",
  "copytags:",
  "spectags:",
  "invtags:",
  "lortags:",
  "metatags:",
  "width:",
  "height:",
  "mpixels:",
  "ratio:",
  "filesize:",
  "date:",
  "source:",
  "description:",
  "note:",
  "delreason:",
  "parent:",
  "pool:",
  "set:",
  "md5:",
  "duration:",
];
