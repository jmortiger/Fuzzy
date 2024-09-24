// https://e621.net/help/cheatsheet
import 'package:e621/middleware.dart';
import 'package:flutter/material.dart';
import 'package:j_util/collections.dart';

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
          "${(types[e] ?? Modifier.add).symbol}"
          "${e.searchString}");

  String get statusString => status.keys.fold(
      "",
      (p, e) => "$p "
          "${(status[e] ?? Modifier.add).symbol}"
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
