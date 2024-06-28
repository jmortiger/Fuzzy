// https://www.liquid-technologies.com/online-json-to-schema-converter
// https://app.quicktype.io/
// import 'package:fuzzy/web/e621/models/tag_d_b.dart';
import 'dart:convert';

import 'package:fuzzy/web/e621/e621.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

import '../../models/image_listing.dart';

typedef JsonOut = Map<String, dynamic>;

abstract class E6Posts {
  Iterable<E6PostResponse> get posts;

  E6PostResponse operator [](int index);
  int get count;
  // E6Posts fromJsonConstructor(JsonOut json);
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
  });
  Set<int> get restrictedIndices;
}

class FullyIteratedArgs extends JEventArgs {
  final List<E6PostResponse> posts;

  const FullyIteratedArgs(this.posts);
}

final class E6PostsLazy extends E6Posts {
  final onFullyIterated = JEvent<FullyIteratedArgs>();
  final _postList = <E6PostResponse>[];
  final _postCapacity = LateFinal<int>();
  int get capacity => _postCapacity.itemSafe ?? -1;
  bool get isFullyProcessed => _postCapacity.isAssigned;
  @override
  int get count => _postList.length;
  final Iterator<E6PostResponse> _postListIterator;
  @override
  final Set<int> restrictedIndices = {};
  @override
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
  }) {
    try {
      if (checkForValidFileUrl) {
        index += restrictedIndices.where((element) => element < index).length;
        while (this[index].file.url == "") {
          restrictedIndices.add(index++);
        }
      }
      return this[index];
      // return (!checkForValidFileUrl || this[index].file.url != "")
      //     ? this[index]
      //     : this[index + 1];
    } catch (e) {
      return null;
    }
  }

  @override
  E6PostResponse operator [](int index) {
    // bool advance() {
    //   try {
    //     return _postListIterator.moveNext();
    //   } catch (e) {
    //     // Show that these failed b/c they're not signed in https://e621.net/help/global_blacklist
    //     return advance();
    //   }
    // }
    if (_postList.length <= index && !_postCapacity.isAssigned) {
      bool mn = false;
      for (var i = _postList.length;
          i <= index && (mn = _postListIterator.moveNext());
          i++) {
        _postList.add(_postListIterator.current);
      }
      if (mn == false && !isFullyProcessed) {
        _postCapacity.item = _postList.length;
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
}

final class E6PostsSync implements E6Posts {
  @override
  final Set<int> restrictedIndices /*  = {} */;
  @override
  final int count;
  @override
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
  }) {
    try {
      if (checkForValidFileUrl) {
        index += restrictedIndices.where((element) => element <= index).length;
      }
      return this[index];
      // return (!checkForValidFileUrl || this[index].file.url != "")
      //     ? this[index]
      //     : this[index + 1];
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

  E6PostsSync({required this.posts})
      : count = posts.length,
        restrictedIndices =
            posts.indicesWhere((e, i, l) => !e.file.hasValidUrl).toSet();
  factory E6PostsSync.fromJson(JsonOut json) => E6PostsSync(
      posts: (json["posts"] as List)
          .mapAsList((e, i, l) => E6PostResponse.fromJson(e)));
}

final class E6PostResponse implements PostListing, e621.Post {
  // #region Json Fields
  /// The ID number of the post.
  @override
  final int id;

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  final DateTime createdAt;

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  @override
  final DateTime updatedAt;

  /// (array group)
  final E6FileResponse file;

  /// (array group)
  final E6Preview preview;

  /// (array group)
  final E6Sample sample;

  /// (array group)
  @override
  final E6Score score;

  /// (array group)
  @override
  final E6PostTags tags;

  @override
  ITagData get tagData => tags;

  /// A JSON array of tags that are locked on the post.
  @override
  final List<String> lockedTags;

  /// An ID that increases for every post alteration on E6 (explained below)
  @override
  final int changeSeq;

  /// (array group)
  @override
  final E6Flags flags;

  /// The post’s rating. Either s, q or e.
  @override
  final String rating;

  /// How many people have favorited the post.
  @override
  final int favCount;

  /// The source field of the post.
  @override
  final List<String> sources;

  /// An array of Pool IDs that the post is a part of.
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
  List<String> get tagList => tags.allTags;
  E6PostResponse({
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

  factory E6PostResponse.fromJson(JsonOut json) => E6PostResponse(
        id: json["id"] as int,
        createdAt: DateTime.parse(json["created_at"]),
        updatedAt: DateTime.parse(json["updated_at"]),
        file: E6FileResponse.fromJson(json["file"]),
        preview: E6Preview.fromJson(json["preview"]),
        sample: E6Sample.fromJson(json["sample"]),
        score: E6Score.fromJson(json["score"]),
        tags: E6PostTags.fromJson(json["tags"]),
        lockedTags: (json["locked_tags"] as List).cast<String>(),
        changeSeq: json["change_seq"] as int,
        flags: E6FlagsBit.fromJson(json["flags"]),
        rating: json["rating"] as String,
        favCount: json["fav_count"] as int,
        sources: (json["sources"] as List).cast<String>(),
        pools: (json["pools"] as List).cast<int>(),
        relationships: E6Relationships.fromJson(json["relationships"]),
        approverId: json["approver_id"] as int?,
        uploaderId: json["uploader_id"] as int,
        description: json["description"] as String,
        commentCount: json["comment_count"] as int,
        isFavorited: json["is_favorited"] as bool,
        hasNotes: json["has_notes"] as bool,
        duration: json["duration"] as num?,
      );
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
        score: score as E6Score? ?? this.score,
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
          : (_address.itemSafe = Uri.tryParse(url)) != null);

  final Late<Uri> _address = Late();
  @override
  Uri get address => Uri.parse(url); */

  E6FileResponse({
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
}

class E6Preview extends e621.Preview implements IImageInfo {
  @override
  String get extension => url.substring(url.lastIndexOf(".") + 1);

  @override
  bool get isAVideo => extension == "webm" || extension == "mp4";

  @override
  bool get hasValidUrl =>
      url.isNotEmpty &&
      (_address.isAssigned
          ? true
          : (_address.itemSafe = Uri.tryParse(url)) != null);

  final _address = LateFinal<Uri>();
  @override
  Uri get address =>
      _address.isAssigned ? _address.$ : _address.itemSafe = Uri.parse(url);

  E6Preview({
    required super.width,
    required super.height,
    required super.url,
  });
  factory E6Preview.fromJson(JsonOut json) => E6Preview(
        width: json["width"],
        height: json["height"],
        url: json["url"] as String? ?? "",
      );
}

class E6Sample extends E6Preview implements ISampleInfo, e621.Sample {
  /// If the post has a sample/thumbnail or not. (True/False)
  @override
  final bool has;

  @override
  bool get isAVideo => extension == "webm" || extension == "mp4";

  E6Sample({
    required this.has,
    required super.width,
    required super.height,
    required super.url,
  });
  factory E6Sample.fromJson(JsonOut json) => E6Sample(
        has: json["has"],
        width: json["width"],
        height: json["height"],
        url: json["url"] as String? ?? "",
      );
}

class E6Score extends e621.Score {
  E6Score({
    required super.up,
    required super.down,
    required super.total,
  });
  factory E6Score.fromJson(JsonOut json) => E6Score(
        up: json["up"] as int,
        down: json["down"] as int,
        total: json["total"] as int,
      );

  @override
  Map<String, dynamic> toJson() => {
        "up": up,
        "down": down,
        "total": total,
      };
}

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

  E6PostTags({
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
        "general": List<dynamic>.from(general.map((x) => x)),
        "species": List<dynamic>.from(species.map((x) => x)),
        "character": List<dynamic>.from(character.map((x) => x)),
        "artist": List<dynamic>.from(artist.map((x) => x)),
        "invalid": List<dynamic>.from(invalid.map((x) => x)),
        "lore": List<dynamic>.from(lore.map((x) => x)),
        "meta": List<dynamic>.from(meta.map((x) => x)),
        "copyright": List<dynamic>.from(copyright.map((x) => x)),
      };
}

class E6Flags extends e621.PostFlags {
  E6Flags({
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

class E6FlagsBit implements E6Flags {
  @override
  bool get deleted => (_data & pendingFlag) == pendingFlag;

  @override
  bool get flagged => (_data & flaggedFlag) == flaggedFlag;

  @override
  bool get noteLocked => (_data & noteLockedFlag) == noteLockedFlag;

  @override
  bool get pending => (_data & statusLockedFlag) == statusLockedFlag;

  @override
  bool get ratingLocked => (_data & ratingLockedFlag) == ratingLockedFlag;

  @override
  bool get statusLocked => (_data & deletedFlag) == deletedFlag;
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
}

class E6Relationships extends e621.PostRelationships {
  E6Relationships({
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
}

/* class Alternates {
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

class Alternate {
  static const types = ["video"];
  int height;
  String type;
  List<String?> urls;
  int width;

  Alternate({
    required this.height,
    required this.type,
    required this.urls,
    required this.width,
  });

  factory Alternate.fromJson(Map<String, dynamic> json) => Alternate(
        height: json["height"],
        type: json["type"],
        urls: List<String?>.from(json["urls"].map((x) => x)),
        width: json["width"],
      );

  Map<String, dynamic> toJson() => {
        "height": height,
        "type": type,
        "urls": List<dynamic>.from(urls.map((x) => x)),
        "width": width,
      };
} */

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
      () async {
        var t1 = (jsonDecode(
          (await E621.performPostSearch(
            tags: postIds.fold(
              "order:id_asc",
              (previousValue, element) => "$previousValue ~id:$element",
            ),
            limit: E621.maxPostsPerSearch,
          ))
              .responseBody,
        )["posts"] as List),
            t2 = postIds.fold(
          <E6PostResponse>[],
          (previousValue, element) {
            return previousValue..add(
              E6PostResponse.fromJson(t1.firstWhere(
                (t) => element == (t["id"] as int),
              )),
            );
          },
        );
        return t2;
      },
    );
  }
  factory PoolModel.fromRawJson(String json) =>
      PoolModel.fromJson(jsonDecode(json));
  PoolModel.fromJson(Map<String, dynamic> json)
      : this(
          id: json["id"],
          name: json["name"],
          createdAt: DateTime.parse(json["created_at"]),
          updatedAt: DateTime.parse(json["updated_at"]),
          creatorId: json["creator_id"],
          description: json["description"],
          isActive: json["is_active"],
          category: e621.PoolCategory.fromJsonString(json["category"]),
          postIds: (json["post_ids"] as List)
              .mapAsList((e, index, list) => e as int),
          creatorName: json["creator_name"],
          postCount: json["post_count"],
        );
  late final LazyInitializer<List<E6PostResponse>> posts;
  static Future<List<E6PostResponse>> getOrderedPosts(List<int> postIds) async {
    var t1 = (jsonDecode(
      (await E621.performPostSearch(
        tags: postIds.fold(
          "order:id_asc",
          (previousValue, element) => "$previousValue ~$element",
        ),
        limit: E621.maxPostsPerSearch,
      ))
          .responseBody,
    )["posts"] as List)
        .fold(
      <E6PostResponse>[],
      (previousValue, element) {
        previousValue[previousValue.indexOf(
          previousValue.firstWhere(
            (t) => (t as int) == (element["id"] as int),
          ),
        )] = E6PostResponse.fromJson(element);
        return previousValue;
      },
    );
    return t1; /* .then((v) {
        (jsonDecode(v.responseBody)["posts"] as List).fold(
          <E6PostResponse>[],
          (previousValue, element) {
            previousValue[previousValue.indexOf(
              previousValue.firstWhere(
                (t) => (t as int) == (element["id"] as int),
              ),
            )] = E6PostResponse.fromJson(element);
            return previousValue;
          },
        );
      }) */
  }
}
