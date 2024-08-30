// https://e621.net/help/cheatsheet
import 'package:flutter/material.dart';
import 'package:j_util/j_util.dart';

mixin SearchableEnum on Enum {
  String get searchString;
}

enum Order with SearchableEnum {
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
  static const matcherStr = "($prefix)([^${RegExpExt.whitespaceCharacters}]+)";
  static final matcher = RegExp(matcherStr);
  static RegExp get matcherGenerated => RegExp(matcherStr);
  static const prefix = "order:";
  final String tagSuffix;

  @override
  String get searchString => "$prefix$tagSuffix";

  const Order(this.tagSuffix);
  factory Order.fromTagText(String tagText) => switch (
          tagText.replaceAll(("$prefix|${RegExpExt.whitespacePattern}"), "")) {
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
      switch (text.replaceAll(("$prefix|${RegExpExt.whitespacePattern}"), "")) {
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
  static Order? retrieveOrderFromSearchString(String str) {
    try {
      return Order.fromTagText(
          Order.matcherGenerated.firstMatch(str)!.group(2)!);
    } catch (e) {
      return null;
    }
  }
}

const prefixModifierMatcher = r"[\-\~\+]|";

enum Rating with SearchableEnum {
  safe,
  questionable,
  explicit;

  static const matcherNonStrictStr =
      "($prefixModifierMatcher)($prefix)([^${RegExpExt.whitespaceCharacters}]+)";
  static final matcherNonStrict = RegExp(matcherNonStrictStr);
  static RegExp get matcherNonStrictGenerated => RegExp(matcherNonStrictStr);
  static const matcherStr =
      "($prefixModifierMatcher)($prefix)(s|q|e|safe|questionable|explicit)";
  static final matcher = RegExp(matcherStr);
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
  static Rating? retrieveRatingFromSearchString(String str) {
    if (!Rating.matcherGenerated.hasMatch(str)) {
      return null;
    }
    final ms = Rating.matcherGenerated.allMatches(str);
    ms.fold(
      <(Modifier, Rating)>{},
      (previousValue, e) => previousValue
        ..add(
          (
            Modifier.fromString(e.group(1) ?? ""),
            Rating.fromTagText(e.group(2)!)
          ),
        ),
    );
    // TODO: FINISH
    throw UnimplementedError("retrieveRatingFromSearchString not implemented");
    return Rating.fromTagText(
        Rating.matcherGenerated.firstMatch(str)!.group(3)!);
  }
}

enum Modifier {
  add,
  remove,
  or;

  const Modifier();
  factory Modifier.fromString(String s) => switch (s) {
        "" => Modifier.add,
        "+" => Modifier.add,
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
  static const dropdownItems = [
    DropdownMenuItem(value: Modifier.add, child: Text("+")),
    DropdownMenuItem(value: Modifier.remove, child: Text("-")),
    DropdownMenuItem(value: Modifier.or, child: Text("~")),
  ];
  static const dropdownItemsFull = [
    DropdownMenuItem(value: Modifier.add, child: Text("+")),
    DropdownMenuItem(value: Modifier.remove, child: Text("-")),
    DropdownMenuItem(value: Modifier.or, child: Text("~")),
    DropdownMenuItem(value: null, child: Icon(Icons.close)),
  ];
}

enum FileType with SearchableEnum {
  jpg,
  png,
  gif,
  swf,
  webm;

  @override
  String get searchString => "rating:$name";
}

enum BooleanSearchTag {
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
}

enum Status with SearchableEnum {
  pending,
  active,
  deleted,
  flagged,
  modqueue,
  any;

  static const prefix = "status:";

  @override
  String get searchString => "$prefix$name";
}

class MetaTagSearchData {
  /// Tristate; true for additive (""/"+"), false for subtractive ("-"), null to exclude;
  bool? addRating;
  Rating rating;
  Order? order;
  Map<FileType, Modifier> types;
  Map<Status, Modifier> status;
  bool? isChild;
  bool? isParent;
  bool? pendingReplacements;
  bool? hasSource;
  bool? hasDescription;
  bool? ratingLocked;
  bool? noteLocked;
  bool? inPool;
  MetaTagSearchData({
    this.order,
    this.addRating,
    this.rating = Rating.safe,
    this.isChild,
    this.isParent,
    this.pendingReplacements,
    this.hasSource,
    this.hasDescription,
    this.ratingLocked,
    this.noteLocked,
    this.inPool,
    Map<FileType, Modifier>? types,
    Map<Status, Modifier>? status,
  })  : status = status ?? {},
        types = types ?? {};
  MetaTagSearchData.req({
    required this.order,
    required this.addRating,
    required this.rating,
    required this.isChild,
    required this.isParent,
    required this.pendingReplacements,
    required this.hasSource,
    required this.hasDescription,
    required this.ratingLocked,
    required this.noteLocked,
    required this.inPool,
    required this.types,
    required this.status,
  });
  static Order? retrieveOrderFromSearchString(String str) {
    try {
      return Order.fromTagText(
          Order.matcherGenerated.firstMatch(str)!.group(2)!);
    } catch (e) {
      return null;
    }
  }

  factory MetaTagSearchData.fromSearchString(String str) {
    throw UnimplementedError(
        "MetaTagSearchData.fromSearchString not implemented");
    // return MetaTagSearchData.req(
    //   order: Order.retrieveOrderFromSearchString(str),
    //   addRating: ,
    //   rating: ,
    //   isChild: ,
    //   isParent: ,
    //   pendingReplacements: ,
    //   hasSource: ,
    //   hasDescription: ,
    //   ratingLocked: ,
    //   noteLocked: ,
    //   inPool: ,
    //   addedTypes: ,
    //   removedTypes: ,
    //   orTypes: ,
    //   addedStatus: ,
    //   removedStatus: ,
    //   orStatus: ,
    // );
  }
  String generateTypeString() => types.keys.fold("",
      (p, e) => "$p ${(types[e] ?? Modifier.add).symbolSlim}${e.searchString}");

  String generateStatusString() => status.keys.fold(
      "",
      (p, e) =>
          "$p ${(status[e] ?? Modifier.add).symbolSlim}${e.searchString}");

  @override
  String toString() {
    var v = "";
    if (order != null) {
      v += " ${order!.searchString}";
    }
    if (addRating != null) {
      v += " ${addRating! ? "" : "-"}${rating.searchString}";
    }
    if (types.isNotEmpty) v += generateTypeString();
    if (status.isNotEmpty) v += generateStatusString();
    if (isChild != null) {
      v += " ${BooleanSearchTag.isChild.tagPrefix}$isChild";
    }
    if (isParent != null) {
      v += " ${BooleanSearchTag.isParent.tagPrefix}$isParent";
    }
    if (pendingReplacements != null) {
      v +=
          " ${BooleanSearchTag.pendingReplacements.tagPrefix}$pendingReplacements";
    }
    if (hasSource != null) {
      v += " ${BooleanSearchTag.hasSource.tagPrefix}$hasSource";
    }
    if (hasDescription != null) {
      v += " ${BooleanSearchTag.hasDescription.tagPrefix}$hasDescription";
    }
    if (ratingLocked != null) {
      v += " ${BooleanSearchTag.ratingLocked.tagPrefix}$ratingLocked";
    }
    if (noteLocked != null) {
      v += " ${BooleanSearchTag.noteLocked.tagPrefix}$noteLocked";
    }
    if (inPool != null) {
      v += " ${BooleanSearchTag.inPool.tagPrefix}$inPool";
    }
    return v;
  }
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
