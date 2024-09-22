// https://www.liquid-technologies.com/online-json-to-schema-converter
// https://app.quicktype.io/
// import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/util.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

// ignore: unnecessary_late
late final _lRecord = lm.generateLogger("E6Models");

typedef JsonOut = Map<String, dynamic>;

abstract class E6Posts with ListMixin<E6PostResponse> {
  Iterable<E6PostResponse> get posts;

  @override
  E6PostResponse operator [](int index);
  int get count;
  // E6Posts fromJsonConstructor(JsonOut json);
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
    bool allowDeleted = true,
    bool filterBlacklist = false,
  });
  Set<int> get restrictedIndices;
  Set<int> get deletedIndices;

  void advanceToEnd();
  Set<int> get unavailableIndices => restrictedIndices.union(deletedIndices);
}

class FullyIteratedArgs extends JEventArgs {
  final List<E6PostResponse> posts;

  const FullyIteratedArgs(this.posts);
}

final class E6PostsLazy extends E6Posts {
  final onFullyIterated = JEvent<FullyIteratedArgs>();
  final _postList = <E6PostResponse>[];
  final _postCapacity = LateFinal<int>();
  int get capacity => _postCapacity.$Safe ?? -1;
  bool get isFullyProcessed => _postCapacity.isAssigned;
  @override
  int get count => _postList.length;
  final Iterator<E6PostResponse> _postListIterator;
  @override
  final Set<int> restrictedIndices = {};
  @override
  final Set<int> deletedIndices = {};
  @override
  Set<int> get unavailableIndices => restrictedIndices.union(deletedIndices);
  @override
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
    bool allowDeleted = true,
    bool filterBlacklist = false,
  }) {
    void iterate() {
      while (this[index].file.url == "") {
        this[index].flags.deleted
            ? deletedIndices.add(index++)
            : restrictedIndices.add(index++);
      }
    }

    try {
      if (checkForValidFileUrl) {
        index += (allowDeleted ? restrictedIndices : unavailableIndices)
            .where((element) => element <= index)
            .length;
        iterate();
      }
      while (filterBlacklist && hasBlacklistedTag(this[index].tagList)) {
        ++index;
        iterate();
      }
      return this[index];
    } catch (e) {
      return null;
    }
  }

  @override
  E6PostResponse operator [](int index) {
    if (_postList.length <= index && !_postCapacity.isAssigned) {
      bool mn = false;
      for (var i = _postList.length;
          i <= index && (mn = _postListIterator.moveNext());
          i++) {
        _postList.add(_postListIterator.current);
      }
      if (mn == false && !isFullyProcessed) {
        _postCapacity.$ = _postList.length;
        onFullyIterated.invoke(FullyIteratedArgs(_postList));
      }
    }
    return _postList[index];
  }

  @override
  final Iterable<E6PostResponse> posts;

  E6PostsLazy({required this.posts}) : _postListIterator = posts.iterator;
  factory E6PostsLazy.fromJson(JsonOut json) => E6PostsLazy(
      posts:
          (json["posts"] as Iterable).map((e) => E6PostResponse.fromJson(e)));
  static Iterable<E6PostResponse> lazyConvertFromJson(JsonOut json) =>
      ((json["posts"] ?? json) as Iterable)
          .map((e) => E6PostResponse.fromJson(e));

  @override
  void advanceToEnd() => tryGet(E621.maxPostsPerSearch + 5);

  @override
  int get length => count;
  @override
  set length(int l) => throw "Non-Modifiable";

  @override
  void operator []=(int index, E6PostResponse value) => throw "Non-Modifiable";
}

final class E6PostsSync extends E6Posts {
  @override
  final Set<int> restrictedIndices = {};
  @override
  final Set<int> deletedIndices = {};
  @override
  Set<int> get unavailableIndices => restrictedIndices.union(deletedIndices);
  @override
  int get count => posts.length;
  @override
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
    bool allowDeleted = true,
    bool filterBlacklist = false,
  }) {
    final filterSet = (allowDeleted ? restrictedIndices : unavailableIndices);
    try {
      if (checkForValidFileUrl) {
        index += filterSet.where((element) => element <= index).length;
      }
      while (filterBlacklist &&
          (filterSet.contains(index) ||
              hasBlacklistedTag(this[index].tagList))) {
        ++index;
      }
      return this[index];
      // return !unavailableIndices.contains(index)
      //     ? this[index]
      //     : this[index].copyWith(
      //         file:
      //             this[index].file.copyWith(url: util.deletedPreviewImagePath));
    } catch (e) {
      return null;
    }
  }

  @override
  E6PostResponse operator [](int index) {
    return posts[index];
  }

  @override
  final List<E6PostResponse> posts;

  E6PostsSync({required this.posts}) {
    for (var i = 0; i < posts.length; i++) {
      if (!posts[i].file.hasValidUrl) {
        posts[i].flags.deleted
            ? deletedIndices.add(i)
            : restrictedIndices.add(i);
      }
    }
  }
  // : restrictedIndices =
  //       posts.indicesWhere((e, i, l) => !e.file.hasValidUrl).toSet();
  factory E6PostsSync.fromJson(JsonOut json) => E6PostsSync(
      posts: (json["posts"] as List)
          .mapAsList((e, i, l) => E6PostMutable.fromJson(e)));
  factory E6PostsSync.fromRawJson(String json) =>
      E6PostsSync.fromJson(jsonDecode(json));

  /// Already fully loaded, so does nothing.
  @override
  void advanceToEnd() {}

  @override
  int get length => posts.length;
  @override
  set length(int l) => posts.length = l; //throw "Non-Modifiable";

  @override
  void operator []=(int index, E6PostResponse value) =>
      posts[index] = value; //throw "Non-Modifiable";
}

class E6PostResponse implements PostListing, e621.Post {
  // #region Json Fields
  /// {@template id}
  /// The ID number of the post.
  /// {@endtemplate}
  @override
  final int id;

  /// {@template createdAt}
  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  /// {@endtemplate}
  @override
  final DateTime createdAt;

  /// {@template updatedAt}
  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  /// {@endtemplate}
  @override
  final DateTime updatedAt;

  /// {@template file}
  /// (array group)
  /// {@endtemplate}
  final E6FileResponse file;

  /// (array group)
  final E6Preview preview;

  /// (array group)
  final E6Sample sample;

  /// (array group)
  @override
  final e621.Score score;

  /// (array group)
  @override
  final E6PostTags tags;

  /// {@template lockedTags}
  /// A JSON array of tags that are locked on the post.
  /// {@endtemplate}
  @override
  final List<String> lockedTags;

  /// {@template changeSeq}
  /// An ID that increases for every post alteration on E6 (explained below)
  /// {@endtemplate}
  @override
  final int changeSeq;

  /// {@template flags}
  /// (array group)
  /// {@endtemplate}
  @override
  final E6Flags flags;

  /// {@template rating}
  /// The post’s rating. Either `s`, `q` or `e`.
  /// {@endtemplate}
  @override
  final String rating;

  /// {@template favCount}
  /// How many people have favorited the post.
  /// {@endtemplate}
  @override
  final int favCount;

  /// {@template sources}
  /// The source field of the post.
  /// {@endtemplate}
  @override
  final List<String> sources;

  /// {@template pools}
  /// An array of Pool IDs that the post is a part of.
  /// {@endtemplate}
  @override
  final List<int> pools;

  /// (array group)
  @override
  final E6Relationships relationships;

  /// The ID of the user that approved the post, if available.
  @override
  final int? approverId;

  /// The ID of the user that uploaded the post.
  @override
  final int uploaderId;

  /// The post’s description.
  @override
  final String description;

  /// The count of comments on the post.
  @override
  final int commentCount;

  /// If provided auth credentials, will return if the authenticated user has
  /// favorited the post or not. If not provided, will be false.
  @override
  final bool isFavorited;

  // #region Not Documented
  /// Guess
  @override
  final bool hasNotes;

  /// If post is a video, the video length. Otherwise, null.
  @override
  final num? duration;
  // #endregion Not Documented
  // #endregion Json Fields

  @override
  ITagData get tagData => tags;
  @override
  List<String> get tagList => tags.allTags;
  bool get isAnimatedGif =>
      file.extension == "gif" && tags.meta.contains("animated");

  /// `true` if the user upvoted this post, `false` if the user downvoted this post, `null` if the user didn't vote on this post.
  bool? get voteState => score is e621.UpdatedScore
      ? (score as e621.UpdatedScore).voteState
      : null;
  // ignore: unnecessary_late
  static late final error = E6PostResponse(
    id: -1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    file: E6FileResponse.error,
    preview: E6Preview.error,
    sample: E6Sample.error,
    score: errorScore,
    tags: E6PostTags.error,
    lockedTags: [],
    changeSeq: -1,
    flags: E6Flags.error,
    rating: "",
    favCount: -1,
    sources: [],
    pools: [],
    relationships: E6Relationships.error,
    approverId: -1,
    uploaderId: -1,
    description: "",
    commentCount: -1,
    isFavorited: false,
    hasNotes: false,
    duration: -1,
  );
  const E6PostResponse({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.file,
    required this.preview,
    required this.sample,
    required this.score,
    required this.tags,
    required this.lockedTags,
    required this.changeSeq,
    required this.flags,
    required this.rating,
    required this.favCount,
    required this.sources,
    required this.pools,
    required this.relationships,
    required this.approverId,
    required this.uploaderId,
    required this.description,
    required this.commentCount,
    required this.isFavorited,
    required this.hasNotes,
    required this.duration,
  });
  factory E6PostResponse.fromRawJson(String json) {
    final t = jsonDecode(json);
    return t["posts"] != null
        ? E6PostResponse.fromJson(t["posts"])
        : t["post"] != null
            ? E6PostResponse.fromJson(t["post"])
            : E6PostResponse.fromJson(t);
  }
  static Iterable<E6PostResponse> fromRawJsonResults(String json) {
    final t = jsonDecode(json);
    return t["posts"] != null
        ? t["posts"].map<E6PostResponse>((e) => E6PostResponse.fromJson(e))
        : [
            t["post"] != null
                ? E6PostResponse.fromJson(t["post"])
                : E6PostResponse.fromJson(t)
          ];
  }

  E6PostResponse.fromJson(JsonOut json)
      : id = json["id"] as int,
        createdAt = DateTime.parse(json["created_at"]),
        updatedAt = DateTime.parse(json["updated_at"]),
        file = E6FileResponse.fromJson(json["file"]
          ..["url"] ??= (json["flags"]["deleted"] as bool) ? deletedUrl : null),
        preview = E6Preview.fromJson(json["preview"]
          ..["url"] ??= (json["flags"]["deleted"] as bool) ? deletedUrl : null),
        sample = E6Sample.fromJson(json["sample"]
          ..["url"] ??= (json["flags"]["deleted"] as bool) ? deletedUrl : null),
        score = e621.Score.fromJson(json["score"]),
        tags = E6PostTags.fromJson(json["tags"]),
        lockedTags = (json["locked_tags"] as List).cast<String>(),
        changeSeq = json["change_seq"] as int,
        flags = E6FlagsBit.fromJson(json["flags"]),
        rating = json["rating"] as String,
        favCount = json["fav_count"] as int,
        sources = (json["sources"] as List).cast<String>(),
        pools = (json["pools"] as List).cast<int>(),
        relationships = E6Relationships.fromJson(json["relationships"]),
        approverId = json["approver_id"] as int?,
        uploaderId = json["uploader_id"] as int,
        description = json["description"] as String,
        commentCount = json["comment_count"] as int,
        isFavorited = json["is_favorited"] as bool,
        hasNotes = json["has_notes"] as bool,
        duration = json["duration"] as num?;
  Map<String, dynamic> toJson() => {
        "id": id,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
        "file": file.toJson(),
        "preview": preview.toJson(),
        "sample": sample.toJson(),
        "score": score.toJson(),
        "tags": tags.toJson(),
        "lockedTags": lockedTags,
        "changeSeq": changeSeq,
        "flags": flags.toJson(),
        "rating": rating,
        "favCount": favCount,
        "sources": sources,
        "pools": pools,
        "relationships": relationships.toJson(),
        "approverId": approverId,
        "uploaderId": uploaderId,
        "description": description,
        "commentCount": commentCount,
        "isFavorited": isFavorited,
        "hasNotes": hasNotes,
        "duration": duration,
      };
  @override
  E6PostResponse copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    e621.File? file,
    e621.Preview? preview,
    e621.Sample? sample,
    e621.Score? score,
    e621.PostTags? tags,
    List<String>? lockedTags,
    int? changeSeq,
    e621.PostFlags? flags,
    String? rating,
    int? favCount,
    List<String>? sources,
    List<int>? pools,
    e621.PostRelationships? relationships,
    int? approverId = -1,
    int? uploaderId,
    String? description,
    int? commentCount,
    bool? isFavorited,
    bool? hasNotes,
    num? duration = -1,
  }) =>
      E6PostResponse(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        file: file as E6FileResponse? ?? this.file,
        preview: preview as E6Preview? ?? this.preview,
        sample: sample as E6Sample? ?? this.sample,
        score: score ?? this.score,
        tags: tags as E6PostTags? ?? this.tags,
        lockedTags: lockedTags ?? this.lockedTags,
        changeSeq: changeSeq ?? this.changeSeq,
        flags: flags as E6Flags? ?? this.flags,
        rating: rating ?? this.rating,
        favCount: favCount ?? this.favCount,
        sources: sources ?? this.sources,
        pools: pools ?? this.pools,
        relationships: relationships as E6Relationships? ?? this.relationships,
        approverId: (approverId ?? 1) < 0 ? approverId : this.approverId,
        uploaderId: uploaderId ?? this.uploaderId,
        description: description ?? this.description,
        commentCount: commentCount ?? this.commentCount,
        isFavorited: isFavorited ?? this.isFavorited,
        hasNotes: hasNotes ?? this.hasNotes,
        duration: (duration ?? 1) < 0 ? duration : this.duration,
      );
}

class E6PostMutable implements E6PostResponse {
  // #region Json Fields
  /// The ID number of the post.
  @override
  int id;

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  DateTime createdAt;

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  DateTime updatedAt;

  /// (array group)
  @override
  E6FileResponse file;

  /// (array group)
  @override
  E6Preview preview;

  /// (array group)
  @override
  E6Sample sample;

  /// (array group)
  @override
  e621.Score score;

  /// (array group)
  @override
  E6PostTags tags;

  /// A JSON array of tags that are locked on the post.
  @override
  List<String> lockedTags;

  /// An ID that increases for every post alteration on E6 (explained below)
  @override
  int changeSeq;

  /// (array group)
  @override
  E6Flags flags;

  /// The post’s rating. Either s, q or e.
  @override
  String rating;

  /// How many people have favorited the post.
  @override
  int favCount;

  /// The source field of the post.
  @override
  List<String> sources;

  /// An array of Pool IDs that the post is a part of.
  @override
  List<int> pools;

  /// (array group)
  @override
  E6Relationships relationships;

  /// The ID of the user that approved the post, if available.
  @override
  int? approverId;

  /// The ID of the user that uploaded the post.
  @override
  int uploaderId;

  /// The post’s description.
  @override
  String description;

  /// The count of comments on the post.
  @override
  int commentCount;

  /// If provided auth credentials, will return if the authenticated user has
  /// favorited the post or not. If not provided, will be false.
  @override
  bool isFavorited;

  // #region Not Documented
  /// Guess
  @override
  bool hasNotes;

  /// If post is a video, the video length. Otherwise, null.
  @override
  num? duration;
  // #endregion Not Documented
  // #endregion Json Fields

  @override
  ITagData get tagData => tags;
  @override
  List<String> get tagList => tags.allTags;
  @override
  bool get isAnimatedGif =>
      file.extension == "gif" && tags.meta.contains("animated");
  @override
  bool? get voteState => score is e621.UpdatedScore
      ? (score as e621.UpdatedScore).voteState
      : null;
  // ignore: unnecessary_late
  static late final error = E6PostMutable(
    id: -1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    file: E6FileResponse.error,
    preview: E6Preview.error,
    sample: E6Sample.error,
    score: errorScore,
    tags: E6PostTags.error,
    lockedTags: [],
    changeSeq: -1,
    flags: E6Flags.error,
    rating: "",
    favCount: -1,
    sources: [],
    pools: [],
    relationships: E6Relationships.error,
    approverId: -1,
    uploaderId: -1,
    description: "",
    commentCount: -1,
    isFavorited: false,
    hasNotes: false,
    duration: -1,
  );
  E6PostMutable({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.file,
    required this.preview,
    required this.sample,
    required this.score,
    required this.tags,
    required this.lockedTags,
    required this.changeSeq,
    required this.flags,
    required this.rating,
    required this.favCount,
    required this.sources,
    required this.pools,
    required this.relationships,
    required this.approverId,
    required this.uploaderId,
    required this.description,
    required this.commentCount,
    required this.isFavorited,
    required this.hasNotes,
    required this.duration,
  });

  factory E6PostMutable.fromJson(JsonOut json) =>
      E6PostMutable.fromInstance(E6PostResponse.fromJson(json));
  factory E6PostMutable.fromRawJson(String json) =>
      E6PostMutable.fromInstance(E6PostResponse.fromRawJson(json));
  static Iterable<E6PostMutable> fromRawJsonResults(String json) {
    final t = jsonDecode(json);
    return t["posts"] != null
        ? t["posts"].map<E6PostMutable>((e) => E6PostMutable.fromJson(e))
        : [
            t["post"] != null
                ? E6PostMutable.fromJson(t["post"])
                : E6PostMutable.fromJson(t)
          ];
  }

  @override
  E6PostMutable copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    e621.File? file,
    e621.Preview? preview,
    e621.Sample? sample,
    e621.Score? score,
    e621.PostTags? tags,
    List<String>? lockedTags,
    int? changeSeq,
    e621.PostFlags? flags,
    String? rating,
    int? favCount,
    List<String>? sources,
    List<int>? pools,
    e621.PostRelationships? relationships,
    int? approverId = -1,
    int? uploaderId,
    String? description,
    int? commentCount,
    bool? isFavorited,
    bool? hasNotes,
    num? duration = -1,
  }) =>
      E6PostMutable(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        file: file as E6FileResponse? ?? this.file,
        preview: preview as E6Preview? ?? this.preview,
        sample: sample as E6Sample? ?? this.sample,
        score: score ?? this.score,
        tags: tags as E6PostTags? ?? this.tags,
        lockedTags: lockedTags ?? this.lockedTags,
        changeSeq: changeSeq ?? this.changeSeq,
        flags: flags as E6Flags? ?? this.flags,
        rating: rating ?? this.rating,
        favCount: favCount ?? this.favCount,
        sources: sources ?? this.sources,
        pools: pools ?? this.pools,
        relationships: relationships as E6Relationships? ?? this.relationships,
        approverId: (approverId ?? 1) < 0 ? approverId : this.approverId,
        uploaderId: uploaderId ?? this.uploaderId,
        description: description ?? this.description,
        commentCount: commentCount ?? this.commentCount,
        isFavorited: isFavorited ?? this.isFavorited,
        hasNotes: hasNotes ?? this.hasNotes,
        duration: (duration ?? 1) < 0 ? duration : this.duration,
      );

  void overwriteWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    e621.File? file,
    e621.Preview? preview,
    e621.Sample? sample,
    e621.Score? score,
    e621.PostTags? tags,
    List<String>? lockedTags,
    int? changeSeq,
    e621.PostFlags? flags,
    String? rating,
    int? favCount,
    List<String>? sources,
    List<int>? pools,
    e621.PostRelationships? relationships,
    int? approverId = -1,
    int? uploaderId,
    String? description,
    int? commentCount,
    bool? isFavorited,
    bool? hasNotes,
    num? duration = -1,
  }) {
    this.id = id ?? this.id;
    this.createdAt = createdAt ?? this.createdAt;
    this.updatedAt = updatedAt ?? this.updatedAt;
    this.file = file as E6FileResponse? ?? this.file;
    this.preview = preview as E6Preview? ?? this.preview;
    this.sample = sample as E6Sample? ?? this.sample;
    this.score = score ?? this.score;
    this.tags = tags as E6PostTags? ?? this.tags;
    this.lockedTags = lockedTags ?? this.lockedTags;
    this.changeSeq = changeSeq ?? this.changeSeq;
    this.flags = flags as E6Flags? ?? this.flags;
    this.rating = rating ?? this.rating;
    this.favCount = favCount ?? this.favCount;
    this.sources = sources ?? this.sources;
    this.pools = pools ?? this.pools;
    this.relationships =
        relationships as E6Relationships? ?? this.relationships;
    this.approverId = (approverId ?? 1) >= 0 ? approverId : this.approverId;
    this.uploaderId = uploaderId ?? this.uploaderId;
    this.description = description ?? this.description;
    this.commentCount = commentCount ?? this.commentCount;
    this.isFavorited = isFavorited ?? this.isFavorited;
    this.hasNotes = hasNotes ?? this.hasNotes;
    this.duration = (duration ?? 1) >= 0 ? duration : this.duration;
  }

  void overwriteFrom(E6PostResponse other) {
    id = other.id;
    createdAt = other.createdAt;
    updatedAt = other.updatedAt;
    file = other.file;
    preview = other.preview;
    sample = other.sample;
    score = other.score;
    tags = other.tags;
    lockedTags = other.lockedTags;
    changeSeq = other.changeSeq;
    flags = other.flags;
    rating = other.rating;
    favCount = other.favCount;
    sources = other.sources;
    pools = other.pools;
    relationships = other.relationships;
    approverId = other.approverId;
    uploaderId = other.uploaderId;
    description = other.description;
    commentCount = other.commentCount;
    isFavorited = other.isFavorited;
    hasNotes = other.hasNotes;
    duration = other.duration;
  }

  E6PostResponse toImmutable() => E6PostResponse(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        file: file,
        preview: preview,
        sample: sample,
        score: score,
        tags: tags,
        lockedTags: lockedTags,
        changeSeq: changeSeq,
        flags: flags,
        rating: rating,
        favCount: favCount,
        sources: sources,
        pools: pools,
        relationships: relationships,
        approverId: approverId,
        uploaderId: uploaderId,
        description: description,
        commentCount: commentCount,
        isFavorited: isFavorited,
        hasNotes: hasNotes,
        duration: duration,
      );
  E6PostMutable.fromInstance(E6PostResponse i)
      : id = i.id,
        createdAt = i.createdAt,
        updatedAt = i.updatedAt,
        file = i.file,
        preview = i.preview,
        sample = i.sample,
        score = i.score,
        tags = i.tags,
        lockedTags = i.lockedTags,
        changeSeq = i.changeSeq,
        flags = i.flags,
        rating = i.rating,
        favCount = i.favCount,
        sources = i.sources,
        pools = i.pools,
        relationships = i.relationships,
        approverId = i.approverId,
        uploaderId = i.uploaderId,
        description = i.description,
        commentCount = i.commentCount,
        isFavorited = i.isFavorited,
        hasNotes = i.hasNotes,
        duration = i.duration;

  @override
  Map<String, dynamic> toJson() => {
        "id": id,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
        "file": file.toJson(),
        "preview": preview.toJson(),
        "sample": sample.toJson(),
        "score": score.toJson(),
        "tags": tags.toJson(),
        "lockedTags": lockedTags,
        "changeSeq": changeSeq,
        "flags": flags.toJson(),
        "rating": rating,
        "favCount": favCount,
        "sources": sources,
        "pools": pools,
        "relationships": relationships.toJson(),
        "approverId": approverId,
        "uploaderId": uploaderId,
        "description": description,
        "commentCount": commentCount,
        "isFavorited": isFavorited,
        "hasNotes": hasNotes,
        "duration": duration,
      };
}

class PostNotifier extends ChangeNotifier implements E6PostMutable {
  // #region Json Fields
  /// The ID number of the post.
  int _id;

  /// The ID number of the post.
  @override
  int get id => _id;

  /// The ID number of the post.
  @override
  set id(int value) {
    _id = value;
    notifyListeners();
  }

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  DateTime _createdAt;

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  DateTime get createdAt => _createdAt;

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  set createdAt(DateTime value) {
    _createdAt = value;
    notifyListeners();
  }

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  DateTime _updatedAt;

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  DateTime get updatedAt => _updatedAt;

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  set updatedAt(DateTime value) {
    _updatedAt = value;
    notifyListeners();
  }

  /// (array group)
  E6FileResponse _file;

  /// (array group)
  @override
  E6FileResponse get file => _file;

  /// (array group)
  @override
  set file(E6FileResponse value) {
    _file = value;
    notifyListeners();
  }

  /// (array group)
  E6Preview _preview;

  /// (array group)
  @override
  E6Preview get preview => _preview;

  /// (array group)
  @override
  set preview(E6Preview value) {
    _preview = value;
    notifyListeners();
  }

  /// (array group)
  E6Sample _sample;

  /// (array group)
  @override
  E6Sample get sample => _sample;

  /// (array group)
  @override
  set sample(E6Sample value) {
    _sample = value;
    notifyListeners();
  }

  /// (array group)
  e621.Score _score;

  /// (array group)
  @override
  e621.Score get score => _score;

  /// (array group)
  @override
  set score(e621.Score value) {
    _score = value;
    notifyListeners();
  }

  /// (array group)
  E6PostTags _tags;

  /// (array group)
  @override
  E6PostTags get tags => _tags;

  /// (array group)
  @override
  set tags(E6PostTags value) {
    _tags = value;
    notifyListeners();
  }

  /// A JSON array of tags that are locked on the post.
  List<String> _lockedTags;

  /// A JSON array of tags that are locked on the post.
  @override
  List<String> get lockedTags => _lockedTags;

  /// A JSON array of tags that are locked on the post.
  @override
  set lockedTags(List<String> value) {
    _lockedTags = value;
    notifyListeners();
  }

  /// An ID that increases for every post alteration on E6 (explained below)
  int _changeSeq;

  /// An ID that increases for every post alteration on E6 (explained below)
  @override
  int get changeSeq => _changeSeq;

  /// An ID that increases for every post alteration on E6 (explained below)
  @override
  set changeSeq(int value) {
    _changeSeq = value;
    notifyListeners();
  }

  /// (array group)
  E6Flags _flags;

  /// (array group)
  @override
  E6Flags get flags => _flags;

  /// (array group)
  @override
  set flags(E6Flags value) {
    _flags = value;
    notifyListeners();
  }

  /// The post’s rating. Either s, q or e.
  String _rating;

  /// The post’s rating. Either s, q or e.
  @override
  String get rating => _rating;

  /// The post’s rating. Either s, q or e.
  @override
  set rating(String value) {
    _rating = value;
    notifyListeners();
  }

  /// How many people have favorited the post.
  int _favCount;

  /// How many people have favorited the post.
  @override
  int get favCount => _favCount;

  /// How many people have favorited the post.
  @override
  set favCount(int value) {
    _favCount = value;
    notifyListeners();
  }

  /// The source field of the post.
  List<String> _sources;

  /// The source field of the post.
  @override
  List<String> get sources => _sources;

  /// The source field of the post.
  @override
  set sources(List<String> value) {
    _sources = value;
    notifyListeners();
  }

  /// An array of Pool IDs that the post is a part of.
  List<int> _pools;

  /// An array of Pool IDs that the post is a part of.
  @override
  List<int> get pools => _pools;

  /// An array of Pool IDs that the post is a part of.
  @override
  set pools(List<int> value) {
    _pools = value;
    notifyListeners();
  }

  /// (array group)
  E6Relationships _relationships;

  /// (array group)
  @override
  E6Relationships get relationships => _relationships;

  /// (array group)
  @override
  set relationships(E6Relationships value) {
    _relationships = value;
    notifyListeners();
  }

  /// The ID of the user that approved the post, if available.
  int? _approverId;

  /// The ID of the user that approved the post, if available.
  @override
  int? get approverId => _approverId;

  /// The ID of the user that approved the post, if available.
  @override
  set approverId(int? value) {
    _approverId = value;
    notifyListeners();
  }

  /// The ID of the user that uploaded the post.
  int _uploaderId;

  /// The ID of the user that uploaded the post.
  @override
  int get uploaderId => _uploaderId;

  /// The ID of the user that uploaded the post.
  @override
  set uploaderId(int value) {
    _uploaderId = value;
  }

  /// The post’s description.
  String _description;

  /// The post’s description.
  @override
  String get description => _description;

  /// The post’s description.
  @override
  set description(String value) {
    _description = value;
    notifyListeners();
  }

  /// The count of comments on the post.
  int _commentCount;

  /// The count of comments on the post.
  @override
  int get commentCount => _commentCount;

  /// The count of comments on the post.
  @override
  set commentCount(int value) {
    _commentCount = value;
    notifyListeners();
  }

  /// If provided auth credentials, will return if the authenticated user has
  /// favorited the post or not. If not provided, will be false.
  bool _isFavorited;

  /// If provided auth credentials, will return if the authenticated user has
  /// favorited the post or not. If not provided, will be false.
  @override
  bool get isFavorited => _isFavorited;

  /// If provided auth credentials, will return if the authenticated user has
  /// favorited the post or not. If not provided, will be false.
  @override
  set isFavorited(bool value) {
    _isFavorited = value;
    notifyListeners();
  }

  // #region Not Documented
  bool _hasNotes;

  @override
  bool get hasNotes => _hasNotes;

  @override
  set hasNotes(bool value) {
    _hasNotes = value;
    notifyListeners();
  }

  /// If post is a video, the video length. Otherwise, null.
  num? _duration;

  /// If post is a video, the video length. Otherwise, null.
  @override
  num? get duration => _duration;

  /// If post is a video, the video length. Otherwise, null.
  @override
  set duration(num? value) {
    _duration = value;
    notifyListeners();
  }
  // #endregion Not Documented
  // #endregion Json Fields

  @override
  ITagData get tagData => tags;
  @override
  List<String> get tagList => tags.allTags;
  @override
  bool get isAnimatedGif =>
      file.extension == "gif" && tags.meta.contains("animated");
  @override
  bool? get voteState => score is e621.UpdatedScore
      ? (score as e621.UpdatedScore).voteState
      : null;
  // ignore: unnecessary_late
  static late final error = PostNotifier(
    id: -1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    file: E6FileResponse.error,
    preview: E6Preview.error,
    sample: E6Sample.error,
    score: errorScore,
    tags: E6PostTags.error,
    lockedTags: [],
    changeSeq: -1,
    flags: E6Flags.error,
    rating: "",
    favCount: -1,
    sources: [],
    pools: [],
    relationships: E6Relationships.error,
    approverId: -1,
    uploaderId: -1,
    description: "",
    commentCount: -1,
    isFavorited: false,
    hasNotes: false,
    duration: -1,
  );
  PostNotifier({
    required int id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required E6FileResponse file,
    required E6Preview preview,
    required E6Sample sample,
    required e621.Score score,
    required E6PostTags tags,
    required List<String> lockedTags,
    required int changeSeq,
    required E6Flags flags,
    required String rating,
    required int favCount,
    required List<String> sources,
    required List<int> pools,
    required E6Relationships relationships,
    required int? approverId,
    required int uploaderId,
    required String description,
    required int commentCount,
    required bool isFavorited,
    required bool hasNotes,
    required num? duration,
  })  : _duration = duration,
        _hasNotes = hasNotes,
        _isFavorited = isFavorited,
        _commentCount = commentCount,
        _description = description,
        _uploaderId = uploaderId,
        _approverId = approverId,
        _relationships = relationships,
        _pools = pools,
        _sources = sources,
        _favCount = favCount,
        _rating = rating,
        _flags = flags,
        _changeSeq = changeSeq,
        _lockedTags = lockedTags,
        _tags = tags,
        _score = score,
        _sample = sample,
        _preview = preview,
        _file = file,
        _updatedAt = updatedAt,
        _createdAt = createdAt,
        _id = id;

  factory PostNotifier.fromJson(JsonOut json) =>
      PostNotifier.fromInstance(E6PostResponse.fromJson(json));
  factory PostNotifier.fromRawJson(String json) =>
      PostNotifier.fromInstance(E6PostResponse.fromRawJson(json));
  static Iterable<PostNotifier> fromRawJsonResults(String json) {
    final t = jsonDecode(json);
    return t["posts"] != null
        ? t["posts"].map<PostNotifier>((e) => PostNotifier.fromJson(e))
        : [
            t["post"] != null
                ? PostNotifier.fromJson(t["post"])
                : PostNotifier.fromJson(t)
          ];
  }

  @override
  PostNotifier copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    e621.File? file,
    e621.Preview? preview,
    e621.Sample? sample,
    e621.Score? score,
    e621.PostTags? tags,
    List<String>? lockedTags,
    int? changeSeq,
    e621.PostFlags? flags,
    String? rating,
    int? favCount,
    List<String>? sources,
    List<int>? pools,
    e621.PostRelationships? relationships,
    int? approverId = -1,
    int? uploaderId,
    String? description,
    int? commentCount,
    bool? isFavorited,
    bool? hasNotes,
    num? duration = -1,
  }) =>
      PostNotifier(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        file: file as E6FileResponse? ?? this.file,
        preview: preview as E6Preview? ?? this.preview,
        sample: sample as E6Sample? ?? this.sample,
        score: score ?? this.score,
        tags: tags as E6PostTags? ?? this.tags,
        lockedTags: lockedTags ?? this.lockedTags,
        changeSeq: changeSeq ?? this.changeSeq,
        flags: flags as E6Flags? ?? this.flags,
        rating: rating ?? this.rating,
        favCount: favCount ?? this.favCount,
        sources: sources ?? this.sources,
        pools: pools ?? this.pools,
        relationships: relationships as E6Relationships? ?? this.relationships,
        approverId: (approverId ?? 1) < 0 ? approverId : this.approverId,
        uploaderId: uploaderId ?? this.uploaderId,
        description: description ?? this.description,
        commentCount: commentCount ?? this.commentCount,
        isFavorited: isFavorited ?? this.isFavorited,
        hasNotes: hasNotes ?? this.hasNotes,
        duration: (duration ?? 1) < 0 ? duration : this.duration,
      );

  @override
  void overwriteWith({
    int? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    e621.File? file,
    e621.Preview? preview,
    e621.Sample? sample,
    e621.Score? score,
    e621.PostTags? tags,
    List<String>? lockedTags,
    int? changeSeq,
    e621.PostFlags? flags,
    String? rating,
    int? favCount,
    List<String>? sources,
    List<int>? pools,
    e621.PostRelationships? relationships,
    int? approverId = -1,
    int? uploaderId,
    String? description,
    int? commentCount,
    bool? isFavorited,
    bool? hasNotes,
    num? duration = -1,
  }) {
    this.id = id ?? this.id;
    this.createdAt = createdAt ?? this.createdAt;
    this.updatedAt = updatedAt ?? this.updatedAt;
    this.file = file as E6FileResponse? ?? this.file;
    this.preview = preview as E6Preview? ?? this.preview;
    this.sample = sample as E6Sample? ?? this.sample;
    this.score = score ?? this.score;
    this.tags = tags as E6PostTags? ?? this.tags;
    this.lockedTags = lockedTags ?? this.lockedTags;
    this.changeSeq = changeSeq ?? this.changeSeq;
    this.flags = flags as E6Flags? ?? this.flags;
    this.rating = rating ?? this.rating;
    this.favCount = favCount ?? this.favCount;
    this.sources = sources ?? this.sources;
    this.pools = pools ?? this.pools;
    this.relationships =
        relationships as E6Relationships? ?? this.relationships;
    this.approverId = (approverId ?? 1) >= 0 ? approverId : this.approverId;
    this.uploaderId = uploaderId ?? this.uploaderId;
    this.description = description ?? this.description;
    this.commentCount = commentCount ?? this.commentCount;
    this.isFavorited = isFavorited ?? this.isFavorited;
    this.hasNotes = hasNotes ?? this.hasNotes;
    this.duration = (duration ?? 1) >= 0 ? duration : this.duration;
  }

  @override
  void overwriteFrom(E6PostResponse other) {
    id = other.id;
    createdAt = other.createdAt;
    updatedAt = other.updatedAt;
    file = other.file;
    preview = other.preview;
    sample = other.sample;
    score = other.score;
    tags = other.tags;
    lockedTags = other.lockedTags;
    changeSeq = other.changeSeq;
    flags = other.flags;
    rating = other.rating;
    favCount = other.favCount;
    sources = other.sources;
    pools = other.pools;
    relationships = other.relationships;
    approverId = other.approverId;
    uploaderId = other.uploaderId;
    description = other.description;
    commentCount = other.commentCount;
    isFavorited = other.isFavorited;
    hasNotes = other.hasNotes;
    duration = other.duration;
  }

  @override
  E6PostResponse toImmutable() => E6PostResponse(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        file: file,
        preview: preview,
        sample: sample,
        score: score,
        tags: tags,
        lockedTags: lockedTags,
        changeSeq: changeSeq,
        flags: flags,
        rating: rating,
        favCount: favCount,
        sources: sources,
        pools: pools,
        relationships: relationships,
        approverId: approverId,
        uploaderId: uploaderId,
        description: description,
        commentCount: commentCount,
        isFavorited: isFavorited,
        hasNotes: hasNotes,
        duration: duration,
      );
  PostNotifier.fromInstance(E6PostResponse i)
      : _id = i.id,
        _createdAt = i.createdAt,
        _updatedAt = i.updatedAt,
        _file = i.file,
        _preview = i.preview,
        _sample = i.sample,
        _score = i.score,
        _tags = i.tags,
        _lockedTags = i.lockedTags,
        _changeSeq = i.changeSeq,
        _flags = i.flags,
        _rating = i.rating,
        _favCount = i.favCount,
        _sources = i.sources,
        _pools = i.pools,
        _relationships = i.relationships,
        _approverId = i.approverId,
        _uploaderId = i.uploaderId,
        _description = i.description,
        _commentCount = i.commentCount,
        _isFavorited = i.isFavorited,
        _hasNotes = i.hasNotes,
        _duration = i.duration;

  @override
  Map<String, dynamic> toJson() => {
        "id": id,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": updatedAt.toIso8601String(),
        "file": file.toJson(),
        "preview": preview.toJson(),
        "sample": sample.toJson(),
        "score": score.toJson(),
        "tags": tags.toJson(),
        "lockedTags": lockedTags,
        "changeSeq": changeSeq,
        "flags": flags.toJson(),
        "rating": rating,
        "favCount": favCount,
        "sources": sources,
        "pools": pools,
        "relationships": relationships.toJson(),
        "approverId": approverId,
        "uploaderId": uploaderId,
        "description": description,
        "commentCount": commentCount,
        "isFavorited": isFavorited,
        "hasNotes": hasNotes,
        "duration": duration,
      };
}

class E6FileResponse extends E6Preview implements e621.File {
  /// The file’s extension.
  @override
  final String ext;
  @override
  String get extension => ext;

  /// The size of the file in bytes.
  @override
  final int size;

  /// The md5 of the file.
  @override
  final String md5;

  /* /// The URL where the file is hosted on E6.
  ///
  /// If auth is not provided, this may be null. This is currently replaced
  /// with an empty string in from json.
  /// https://e621.net/help/global_blacklist
  @override
  final String url;
  bool get hasValidUrl =>
      url.isNotEmpty &&
      (_address.isAssigned
          ? true
          : (_address.$Safe = Uri.tryParse(url)) != null);

  final Late<Uri> _address = Late();
  @override
  Uri get address => Uri.parse(url); */
  static const error = E6FileResponse(
    width: -1,
    height: -1,
    ext: "",
    size: -1,
    md5: "",
    url: "",
  );
  const E6FileResponse({
    required super.width,
    required super.height,
    required this.ext,
    required this.size,
    required this.md5,
    required super.url,
  });
  factory E6FileResponse.fromJson(JsonOut json) => E6FileResponse(
        width: json["width"] as int,
        height: json["height"] as int,
        ext: json["ext"] as String,
        size: json["size"] as int,
        md5: json["md5"] as String,
        url: json["url"] as String? ?? "",
      );
  @override
  JsonOut toJson() => {
        "width": width,
        "height": height,
        "ext": ext,
        "size": size,
        "md5": md5,
        "url": url,
      };
  @override
  E6FileResponse copyWith({
    String? ext,
    int? size,
    String? md5,
    String? url,
    int? width,
    int? height,
  }) =>
      E6FileResponse(
        ext: ext ?? this.ext,
        size: size ?? this.size,
        md5: md5 ?? this.md5,
        height: height ?? this.height,
        url: url ?? this.url,
        width: width ?? this.width,
      );
}

class E6Preview extends e621.Preview with IImageInfo, RetrieveImageProvider {
  @override
  String get extension => url.substring(url.lastIndexOf(".") + 1);

  @override
  bool get isAVideo => extension == "webm" || extension == "mp4";

  @override
  Uri get address => Uri.parse(url);

  static const error = E6Preview(
    width: -1,
    height: -1,
    url: "",
  );

  const E6Preview({
    required super.width,
    required super.height,
    required super.url,
  });
  factory E6Preview.fromJson(JsonOut json) => E6Preview(
        width: json["width"],
        height: json["height"],
        url: json["url"] as String? ?? "",
      );
  JsonOut toJson() => {
        "width": width,
        "height": height,
        "url": url,
      };
}

class E6Sample extends E6Preview implements ISampleInfo, e621.Sample {
  /// If the post has a sample/thumbnail or not. (True/False)
  @override
  final bool has;

  final Alternates? alternates;

  @override
  bool get isAVideo => extension == "webm" || extension == "mp4";

  static const error = E6Sample(
    has: false,
    width: -1,
    height: -1,
    url: "",
  );

  const E6Sample({
    required this.has,
    required super.width,
    required super.height,
    required super.url,
    this.alternates,
  });
  factory E6Sample.fromJson(JsonOut json) => E6Sample(
        has: json["has"],
        width: json["width"],
        height: json["height"],
        url: json["url"] as String? ?? "",
        alternates: json["alternates"] != null
            ? Alternates.fromJson(json["alternates"])
            : null,
      );
  @override
  JsonOut toJson() => {
        "has": has,
        "width": width,
        "height": height,
        "url": url,
        "alternates": alternates?.toJson(),
      };
}

const errorScore = e621.Score(
  up: -1,
  down: -1,
  total: -1,
);
// class E6Score extends e621.Score {
//   static const error = E6Score(
//     up: -1,
//     down: -1,
//     total: -1,
//   );

//   const E6Score({
//     required super.up,
//     required super.down,
//     required super.total,
//   });
//   factory E6Score.fromJson(JsonOut json) => E6Score(
//         up: json["up"] as int,
//         down: json["down"] as int,
//         total: json["total"] as int,
//       );

//   @override
//   Map<String, dynamic> toJson() => {
//         "up": up,
//         "down": down,
//         "total": total,
//       };

//   @override
//   E6Score copyWith({
//     int? up,
//     int? down,
//     int? total,
//   }) =>
//       E6Score(
//         up: up ?? this.up,
//         down: down ?? this.down,
//         total: total ?? this.total,
//       );
// }

class E6PostTags extends e621.PostTags implements ITagData {
  List<String> get allTags => [
        ...general,
        ...species,
        ...character,
        ...artist,
        ...invalid,
        ...lore,
        ...meta
      ];
  @override
  List<String> getByCategory(e621.TagCategory c) =>
      getByCategorySafe(c) ??
      (throw ArgumentError.value(c, "c", "Can't be TagCategory._error"));
  @override
  List<String>? getByCategorySafe(e621.TagCategory c) => switch (c) {
        e621.TagCategory.general => general,
        e621.TagCategory.species => species,
        e621.TagCategory.character => character,
        e621.TagCategory.artist => artist,
        e621.TagCategory.invalid => invalid,
        e621.TagCategory.lore => lore,
        e621.TagCategory.meta => meta,
        e621.TagCategory.copyright => copyright,
        _ => null,
      };
  static const error = E6PostTags(
    general: ["ERROR"],
    species: ["ERROR"],
    character: ["ERROR"],
    artist: ["ERROR"],
    invalid: ["ERROR"],
    lore: ["ERROR"],
    meta: ["ERROR"],
    copyright: ["ERROR"],
  );
  const E6PostTags({
    required super.general,
    required super.species,
    required super.character,
    required super.artist,
    required super.invalid,
    required super.lore,
    required super.meta,
    required super.copyright,
  });
  factory E6PostTags.fromJson(JsonOut json) => E6PostTags(
        general: (json["general"] as List).cast<String>(),
        species: (json["species"] as List).cast<String>(),
        character: (json["character"] as List).cast<String>(),
        artist: (json["artist"] as List).cast<String>(),
        invalid: (json["invalid"] as List).cast<String>(),
        lore: (json["lore"] as List).cast<String>(),
        meta: (json["meta"] as List).cast<String>(),
        copyright: (json["copyright"] as List).cast<String>(),
      );

  @override
  Map<String, dynamic> toJson() => {
        "general": general,
        "species": species,
        "character": character,
        "artist": artist,
        "invalid": invalid,
        "lore": lore,
        "meta": meta,
        "copyright": copyright,
      };
  static const specialTags = [
    "anonymous_artist",
    "avoid_posting",
    "conditional_dnp",
    "epilepsy_warning",
    "jumpscare_warning",
    "sound_warning",
    "third-party_edit",
    "unknown_artist",
    "unknown_artist_signature",
    // Character
    "unknown_character",
    "anonymous_character",
    "background_character",
    "nameless_character",
  ];
  static const metaTagsUnderArtistCategory = [
    "epilepsy_warning",
    "jumpscare_warning",
    "sound_warning",
    "third-party_edit",
    "unknown_artist_signature",
  ];
  static const specialArtistTags = [
    "anonymous_artist",
    "avoid_posting",
    "conditional_dnp",
    "epilepsy_warning",
    "jumpscare_warning",
    "sound_warning",
    "third-party_edit",
    "unknown_artist",
    "unknown_artist_signature",
  ];
  static const specialCharacterTags = [
    "unknown_character",
    "anonymous_character",
    "background_character",
    "nameless_character",
  ];

  /// Has a listed artist (i.e. contains something other than special artist tags like "third-party_edit").
  bool get hasArtist => artist.any((e) => !specialArtistTags.contains(e));
  Iterable<String> get artistFiltered =>
      artist.where((e) => !specialArtistTags.contains(e));

  /// Has a listed character (i.e. contains something other than special artist tags like "unknown_character").
  bool get hasCharacter =>
      character.any((e) => !specialCharacterTags.contains(e));
  Iterable<String> get characterFiltered =>
      character.where((e) => !specialCharacterTags.contains(e));
}

class E6Flags extends e621.PostFlags {
  static const error = E6Flags(
    pending: true,
    flagged: true,
    noteLocked: true,
    statusLocked: true,
    ratingLocked: true,
    deleted: true,
  );
  const E6Flags({
    required super.pending,
    required super.flagged,
    required super.noteLocked,
    required super.statusLocked,
    required super.ratingLocked,
    required super.deleted,
  });
  factory E6Flags.fromJson(JsonOut json) => E6Flags(
        pending: json["pending"] as bool,
        flagged: json["flagged"] as bool,
        noteLocked: json["note_locked"] as bool,
        statusLocked: json["status_locked"] as bool,
        ratingLocked: json["rating_locked"] as bool,
        deleted: json["deleted"] as bool,
      );
  JsonOut toJson() => {
        "pending": pending,
        "flagged": flagged,
        "noteLocked": noteLocked,
        "statusLocked": statusLocked,
        "ratingLocked": ratingLocked,
        "deleted": deleted,
      };

  // @override
  E6Flags copyWith({
    bool? pending,
    bool? flagged,
    bool? noteLocked,
    bool? statusLocked,
    bool? ratingLocked,
    bool? deleted,
  }) =>
      E6Flags(
        pending: pending ?? this.pending,
        flagged: flagged ?? this.flagged,
        noteLocked: noteLocked ?? this.noteLocked,
        statusLocked: statusLocked ?? this.statusLocked,
        ratingLocked: ratingLocked ?? this.ratingLocked,
        deleted: deleted ?? this.deleted,
      );
}

enum PostFlags {
  /// int.parse("000001", radix: 2);
  pending(bit: 1),

  /// int.parse("000010", radix: 2);
  flagged(bit: 2),

  /// int.parse("000100", radix: 2);
  noteLocked(bit: 4),

  /// int.parse("001000", radix: 2);
  statusLocked(bit: 8),

  /// int.parse("010000", radix: 2);
  ratingLocked(bit: 16),

  /// int.parse("100000", radix: 2);
  deleted(bit: 32);

  final int bit;
  const PostFlags({required this.bit});

  /// int.parse("000001", radix: 2);
  static const int pendingFlag = 1;

  /// int.parse("000010", radix: 2);
  static const int flaggedFlag = 2;

  /// int.parse("000100", radix: 2);
  static const int noteLockedFlag = 4;

  /// int.parse("001000", radix: 2);
  static const int statusLockedFlag = 8;

  /// int.parse("010000", radix: 2);
  static const int ratingLockedFlag = 16;

  /// int.parse("100000", radix: 2);
  static const int deletedFlag = 32;
  static int toInt(PostFlags f) => f.bit;
  static List<PostFlags> getFlags(int f) {
    var l = <PostFlags>[];
    if (f & pending.bit == pending.bit) l.add(pending);
    if (f & flagged.bit == flagged.bit) l.add(flagged);
    if (f & noteLocked.bit == noteLocked.bit) l.add(noteLocked);
    if (f & statusLocked.bit == statusLocked.bit) l.add(statusLocked);
    if (f & ratingLocked.bit == ratingLocked.bit) l.add(ratingLocked);
    if (f & deleted.bit == deleted.bit) l.add(deleted);
    return l;
  }

  bool hasFlag(int f) => (PostFlags.toInt(this) & f) == PostFlags.toInt(this);
}

class E6FlagsBit implements E6Flags, e621.PostFlags {
  @override
  bool get deleted => (_data & deletedFlag) == deletedFlag;

  @override
  bool get flagged => (_data & flaggedFlag) == flaggedFlag;

  @override
  bool get noteLocked => (_data & noteLockedFlag) == noteLockedFlag;

  @override
  bool get pending => (_data & pendingFlag) == pendingFlag;

  @override
  bool get ratingLocked => (_data & ratingLockedFlag) == ratingLockedFlag;

  @override
  bool get statusLocked => (_data & statusLockedFlag) == statusLockedFlag;
  final int _data;
  E6FlagsBit({
    required bool pending,
    required bool flagged,
    required bool noteLocked,
    required bool statusLocked,
    required bool ratingLocked,
    required bool deleted,
  }) : _data = (pending ? pendingFlag : 0) +
            (flagged ? flaggedFlag : 0) +
            (noteLocked ? noteLockedFlag : 0) +
            (statusLocked ? statusLockedFlag : 0) +
            (ratingLocked ? ratingLockedFlag : 0) +
            (deleted ? deletedFlag : 0);
  factory E6FlagsBit.fromJson(JsonOut json) => E6FlagsBit(
        pending: json["pending"] as bool,
        flagged: json["flagged"] as bool,
        noteLocked: json["note_locked"] as bool,
        statusLocked: json["status_locked"] as bool,
        ratingLocked: json["rating_locked"] as bool,
        deleted: json["deleted"] as bool,
      );
  static int getValue({
    bool pending = false,
    bool flagged = false,
    bool noteLocked = false,
    bool statusLocked = false,
    bool ratingLocked = false,
    bool deleted = false,
  }) =>
      (pending ? pendingFlag : 0) +
      (flagged ? flaggedFlag : 0) +
      (noteLocked ? noteLockedFlag : 0) +
      (statusLocked ? statusLockedFlag : 0) +
      (ratingLocked ? ratingLockedFlag : 0) +
      (deleted ? deletedFlag : 0);

  static const int pendingFlag = 1; //int.parse("000001", radix: 2);
  static const int flaggedFlag = 2; //int.parse("000010", radix: 2);
  static const int noteLockedFlag = 4; //int.parse("000100", radix: 2);
  static const int statusLockedFlag = 8; //int.parse("001000", radix: 2);
  static const int ratingLockedFlag = 16; //int.parse("010000", radix: 2);
  static const int deletedFlag = 32; //int.parse("100000", radix: 2);

  @override
  E6FlagsBit copyWith({
    bool? pending,
    bool? flagged,
    bool? noteLocked,
    bool? statusLocked,
    bool? ratingLocked,
    bool? deleted,
  }) =>
      E6FlagsBit(
        pending: pending ?? this.pending,
        flagged: flagged ?? this.flagged,
        noteLocked: noteLocked ?? this.noteLocked,
        statusLocked: statusLocked ?? this.statusLocked,
        ratingLocked: ratingLocked ?? this.ratingLocked,
        deleted: deleted ?? this.deleted,
      );

  @override
  JsonOut toJson() => {
        "pending": pending,
        "flagged": flagged,
        "noteLocked": noteLocked,
        "statusLocked": statusLocked,
        "ratingLocked": ratingLocked,
        "deleted": deleted,
      };
}

class E6Relationships extends e621.PostRelationships {
  static const error = E6Relationships(
    parentId: -1,
    hasChildren: false,
    hasActiveChildren: false,
    children: [],
  );
  const E6Relationships({
    required super.parentId,
    required super.hasChildren,
    required super.hasActiveChildren,
    required super.children,
  });
  factory E6Relationships.fromJson(JsonOut json) => E6Relationships(
        parentId: json["parent_id"] as int?,
        hasChildren: json["has_children"] as bool,
        hasActiveChildren: json["has_active_children"] as bool,
        children: (json["children"] as List).cast<int>(),
      );
  JsonOut toJson() => {
        "parentId": parentId,
        "hasChildren": hasChildren,
        "hasActiveChildren": hasActiveChildren,
        "children": children,
      };
}

class Alternates {
  Alternate? the480P;
  Alternate? the720P;
  Alternate? original;
  Map<String, Alternate> alternates;

  Alternates({
    this.the480P,
    this.the720P,
    this.original,
    required this.alternates,
  });

  factory Alternates.fromJson(Map<String, dynamic> json) => Alternates(
        the480P: json["480p"] == null ? null : Alternate.fromJson(json["480p"]),
        the720P: json["720p"] == null ? null : Alternate.fromJson(json["720p"]),
        original: json["original"] == null
            ? null
            : Alternate.fromJson(json["original"]),
        alternates: {
          for (var e in json.entries)
            e.key: Alternate.fromJson(e.value as JsonOut)
        },
      );

  Map<String, dynamic> toJson() => {
        "480p": the480P?.toJson(),
        "720p": the720P?.toJson(),
        "original": original?.toJson(),
      };
}

class Alternate extends e621.Alternate with IImageInfo {
  static const types = ["video"];
  // @override
  // int height;
  // String type;
  // List<String?> urls;
  // @override
  // int width;

  @override
  Uri get address => Uri.parse(url);

  @override
  String get extension => IImageInfoBare.extensionImpl(this);

  @override
  bool get hasValidUrl => (urls[0] ?? urls[1]) != null;

  @override
  bool get isAVideo => true;

  @override
  String get url => urls[0] ?? urls[1]!;
  Alternate({
    required super.height,
    required super.type,
    required super.urls,
    required super.width,
  });

  factory Alternate.fromJson(Map<String, dynamic> json) => Alternate(
        height: json["height"],
        type: json["type"],
        urls: List<String?>.from(json["urls"].map((x) => x)),
        width: json["width"],
      );

  // @override
  // Map<String, dynamic> toJson() => {
  //       "height": height,
  //       "type": type,
  //       "urls": List<dynamic>.from(urls.map((x) => x)),
  //       "width": width,
  //     };
}

enum PostDataType {
  png,
  jpg,
  gif,
  webm,
  mp4,
  swf;

  bool isResourceOfDataType(String url) =>
      url.endsWith(toString()) ||
      (this == PostDataType.jpg && url.endsWith("jpeg"));
}

enum PostType {
  image,
  video,
  flash,
  ;
}

class PoolModel extends e621.Pool {
  // #region Logger
  static lm.Printer get print => _lRecord.print;
  static lm.FileLogger get logger => _lRecord.logger;
  // // ignore: unnecessary_late
  // static late final lRecord = lm.generateLogger("PoolModel");
  // #endregion Logger
  PoolModel({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    required super.creatorId,
    required super.description,
    required super.isActive,
    required super.category,
    required super.postIds,
    required super.creatorName,
    required super.postCount,
  }) {
    posts = LazyInitializer<List<E6PostResponse>>(
      () async => getOrderedPosts(postIds, poolId: id),
    );
  }
  factory PoolModel.fromRawJson(String json) =>
      PoolModel.fromJson(jsonDecode(json));
  factory PoolModel.fromInstance(e621.Pool i) => PoolModel(
        id: i.id,
        name: i.name,
        createdAt: i.createdAt,
        updatedAt: i.updatedAt,
        creatorId: i.creatorId,
        description: i.description,
        isActive: i.isActive,
        category: i.category,
        postIds: i.postIds,
        creatorName: i.creatorName,
        postCount: i.postCount,
      );
  PoolModel.fromJson(Map<String, dynamic> json)
      : this(
          id: json["id"],
          name: json["name"],
          createdAt: DateTime.parse(json["created_at"]),
          updatedAt: DateTime.parse(json["updated_at"]),
          creatorId: json["creator_id"],
          description: json["description"],
          isActive: json["is_active"],
          category: e621.PoolCategory.fromJson(json["category"]),
          postIds: (json["post_ids"] as List).cast<int>(),
          // .mapAsList((e, index, list) => e as int),
          creatorName: json["creator_name"],
          postCount: json["post_count"],
        );
  late final LazyInitializer<List<E6PostResponse>> posts;
  String get namePretty => name.replaceAll("_", " ");

  Future<List<E6PostResponse>> getPosts({
    int page = 1,
    int? postsPerPage,
  }) =>
      getOrderedPosts(
        postIds,
        poolId: id,
        postsPerPage: postsPerPage,
        page: page,
      );

  /// TODO: Still not iron-clad in terms of ordering and page offsets.
  ///
  /// Uses `order:id_asc` to try and grab them in order. If there are too many
  /// posts and a lot are out of order, this could cause failure somewhere.
  static Future<List<E6PostResponse>> getOrderedPosts(
    List<int> postIds, {
    int? poolId,
    int? postsPerPage,
    int page = 1,
  }) async {
    if (page <= 0) page = 1;
    postsPerPage ??= SearchView.i.postsPerPage;
    if (postIds.length > e621.maxPostsPerSearch) {
      logger.warning("Too many posts in pool for a single search request");
    } else if (postIds.length > postsPerPage) {
      logger.warning("Too many posts in pool for 1 page");
    } else if (poolId == null && postIds.length > e621.maxTagsPerSearch - 1) {
      logger.warning("Too many posts in pool for 1 search (use the pool id)");
      postsPerPage = e621.maxTagsPerSearch - 1;
    }
    try {
      final searchString =
          "${(poolId != null ? "pool:$poolId" : postIds.getRange(
                0,
                min(postIds.length, postsPerPage),
              ).fold(
                "",
                (previousValue, element) => "$previousValue~id:$element ",
              ))} order:id_asc";
      final response = await E621.performPostSearch(
          tags: searchString, limit: postsPerPage, pageNumber: page);
      logger.finer("first: ${postIds.first}");
      logger.finer(response.responseBody);
      logger.finer(response.statusCode);
      final t1 = (jsonDecode(
        (response).responseBody,
      )["posts"] as List);
      logger.finer("# posts in response: ${t1.length}");
      int postOffset = (page - 1) * postsPerPage;
      logger.finer(
          "offset from start of poolIds[$postOffset] = ${postIds[postOffset]}");
      // Sort them by order in pool
      final t2 = postIds.getRange(postOffset, postIds.length).reduceUntilTrue(
        (acc, e, i, l) {
          var match =
              t1.firstWhere((t) => e == (t["id"] as int), orElse: () => null);
          return match != null
              ? ((acc..add(E6PostResponse.fromJson(match))), false)
              // Force it to stay alive until it's at least close.
              : (acc, acc.length > l.length);
        },
        <E6PostResponse>[],
      );
      logger.finer("# posts after sorting: ${t2.length}");
      if (t1.length != t2.length) {
        logger.warning(
            "# posts before ${t1.length} & after ${t2.length} sorting mismatched. There is likely 1 or more posts whose id is out of order with its order in the pool. This will likely cause problems.");
      }
      return t2;
    } catch (e, s) {
      logger.severe(
          "Failed to getOrderedPosts(poolId: $poolId, postsPerPage: $postsPerPage, page: $page), defaulting to empty array. PostIds: $postIds",
          e,
          s);
      return [];
    }
  }
}

class SetModel extends e621.PostSet {
  static lm.FileLogger get logger => _lRecord.logger;
  SetModel({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    required super.creatorId,
    required super.isPublic,
    required super.name,
    required super.shortname,
    required super.description,
    required super.postCount,
    required super.transferOnDelete,
    required super.postIds,
  }) {
    posts = LazyInitializer<List<E6PostResponse>>(
      () async => getOrderedPosts(postIds, setId: id),
    );
  }
  factory SetModel.fromRawJson(String json) =>
      SetModel.fromJson(jsonDecode(json));
  factory SetModel.fromInstance(e621.PostSet i) => SetModel(
        id: i.id,
        createdAt: i.createdAt,
        updatedAt: i.updatedAt,
        creatorId: i.creatorId,
        isPublic: i.isPublic,
        name: i.name,
        shortname: i.shortname,
        description: i.description,
        postCount: i.postCount,
        transferOnDelete: i.transferOnDelete,
        postIds: i.postIds,
      );
  SetModel.fromJson(Map<String, dynamic> json)
      : this(
          id: json["id"],
          name: json["name"],
          createdAt: DateTime.parse(json["created_at"]),
          updatedAt: DateTime.parse(json["updated_at"]),
          creatorId: json["creator_id"],
          isPublic: json["is_public"],
          shortname: json["shortname"],
          description: json["description"],
          postCount: json["post_count"],
          transferOnDelete: json["transfer_on_delete"],
          postIds: (json["post_ids"] as List).cast<int>(),
        );
  late final LazyInitializer<List<E6PostResponse>> posts;
  @Deprecated("Use name")
  String get namePretty => name; //name.replaceAll("_", " ");

  Future<List<E6PostResponse>> getPosts({
    int page = 1,
    int? postsPerPage,
  }) =>
      getOrderedPosts(
        postIds,
        setId: id,
        postsPerPage: postsPerPage,
        page: page,
      );

  /// TODO: Still not iron-clad in terms of ordering and page offsets.
  ///
  /// Uses `order:id_asc` to try and grab them in order. If there are too many
  /// posts and a lot are out of order, this could cause failure somewhere.
  static Future<List<E6PostResponse>> getOrderedPosts(
    List<int> postIds, {
    int? setId,
    int? postsPerPage,
    int page = 1,
  }) async {
    if (page <= 0) page = 1;
    postsPerPage ??= SearchView.i.postsPerPage;
    if (postIds.length > e621.maxPostsPerSearch) {
      logger.warning("Too many posts in set for a single search request");
    } else if (postIds.length > postsPerPage) {
      logger.warning("Too many posts in set for 1 page");
    } else if (setId == null && postIds.length > e621.maxTagsPerSearch - 1) {
      logger.warning("Too many posts in set for 1 search (use the set id)");
      postsPerPage = e621.maxTagsPerSearch - 1;
    }
    try {
      final searchString = "${(setId != null ? "set:$setId" : postIds.getRange(
            0,
            min(postIds.length, postsPerPage),
          ).fold(
            "",
            (previousValue, element) => "$previousValue~id:$element ",
          ))} order:id_asc";
      final response = await E621.performPostSearch(
          tags: searchString, limit: postsPerPage, pageNumber: page);
      logger.finer("first: ${postIds.first}");
      logger.finer(response.responseBody);
      logger.finer(response.statusCode);
      final t1 = (jsonDecode(
        (response).responseBody,
      )["posts"] as List);
      logger.finer("# posts in response: ${t1.length}");
      int postOffset = (page - 1) * postsPerPage;
      logger.finer(
          "offset from start of setIds[$postOffset] = ${postIds[postOffset]}");
      // Sort them by order in set
      final t2 = postIds.getRange(postOffset, postIds.length).reduceUntilTrue(
        (acc, e, i, l) {
          var match =
              t1.firstWhere((t) => e == (t["id"] as int), orElse: () => null);
          return match != null
              ? ((acc..add(E6PostResponse.fromJson(match))), false)
              // Force it to stay alive until it's at least close.
              : (acc, acc.length > l.length);
        },
        <E6PostResponse>[],
      );
      logger.finer("# posts after sorting: ${t2.length}");
      if (t1.length != t2.length) {
        logger.warning(
            "# posts before ${t1.length} & after ${t2.length} sorting mismatched. There is likely 1 or more posts whose id is out of order with its order in the set. This will likely cause problems.");
      }
      return t2;
    } catch (e, s) {
      logger.severe(
          "Failed to getOrderedPosts(setId: $setId, postsPerPage: $postsPerPage, page: $page), defaulting to empty array. PostIds: $postIds",
          e,
          s);
      return [];
    }
  }
}
