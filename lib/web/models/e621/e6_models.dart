// https://www.liquid-technologies.com/online-json-to-schema-converter
// https://app.quicktype.io/
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:j_util/j_util_full.dart';

import '../image_listing.dart';

typedef JsonOut = Map<String, dynamic>;

abstract class E6Posts {
  Iterable<E6PostResponse> get posts;

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

final class E6PostResponse implements PostListing {
  // #region Json Fields
  /// The ID number of the post.
  @override
  final int id;

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  final String createdAt;

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  final String updatedAt;

  /// (array group)
  @override
  final E6FileResponse file;

  /// (array group)
  @override
  final E6Preview preview;

  /// (array group)
  @override
  final E6Sample sample;

  /// (array group)
  final E6Score score;

  /// (array group)
  final E6PostTags tags;

  /// A JSON array of tags that are locked on the post.
  final List<String> lockedTags;

  /// An ID that increases for every post alteration on E6 (explained below)
  final int changeSeq;

  /// (array group)
  final E6Flags flags;

  /// The post’s rating. Either s, q or e.
  final String rating;

  /// How many people have favorited the post.
  final int favCount;

  /// The source field of the post.
  final List<String> sources;

  /// An array of Pool IDs that the post is a part of.
  final List<String> pools;

  /// (array group)
  final E6Relationships relationships;

  /// The ID of the user that approved the post, if available.
  final int? approverId;

  /// The ID of the user that uploaded the post.
  final int uploaderId;

  /// The post’s description.
  final String description;

  /// The count of comments on the post.
  final int commentCount;

  /// If provided auth credentials, will return if the authenticated user has
  /// favorited the post or not. If not provided, will be false.
  final bool isFavorited;

  // #region Not Documented
  /// Guess
  final bool hasNotes;

  /// If post is a video, the video length. Otherwise, null.
  final num? duration;
  // #endregion Not Documented
  // #endregion Json Fields

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
        createdAt: json["created_at"] as String,
        updatedAt: json["updated_at"] as String,
        file: E6FileResponse.fromJson(json["file"] as JsonOut),
        preview: E6Preview.fromJson(json["preview"] as JsonOut),
        sample: E6Sample.fromJson(json["sample"] as JsonOut),
        score: E6Score.fromJson(json["score"] as JsonOut),
        tags: E6PostTags.fromJson(json["tags"] as JsonOut),
        lockedTags: (json["locked_tags"] as List).cast<String>(),
        changeSeq: json["change_seq"] as int,
        flags: E6FlagsBit.fromJson(json["flags"] as JsonOut),
        rating: json["rating"] as String,
        favCount: json["fav_count"] as int,
        sources: (json["sources"] as List).cast<String>(),
        pools: (json["pools"] as List).cast<String>(),
        relationships:
            E6Relationships.fromJson(json["relationships"] as JsonOut),
        approverId: json["approver_id"] as int?,
        uploaderId: json["uploader_id"] as int,
        description: json["description"] as String,
        commentCount: json["comment_count"] as int,
        isFavorited: json["is_favorited"] as bool,
        hasNotes: json["has_notes"] as bool,
        duration: json["duration"] as num?,
      );
}

/// TODO: Extend [E6Preview]?
class E6FileResponse extends E6Preview {
  /* /// The width of the post.
  @override
  final int width;

  /// The height of the post.
  @override
  final int height; */

  /// The file’s extension.
  final String ext;
  @override
  String get extension => ext;

  /// The size of the file in bytes.
  final int size;

  /// The md5 of the file.
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

class E6Preview implements IImageInfo {
  /// The width of the post preview.
  @override
  final int width;

  /// The height of the post preview.
  @override
  final int height;

  @override
  String get extension => url.substring(url.lastIndexOf(".") + 1);

  @override
  bool get isAVideo => extension == "webm" || extension == "mp4";

  /// {@template E6Preview.url}
  ///
  /// The URL where the preview file is hosted on E6
  ///
  /// If auth is not provided, this may be null. This is currently replaced
  /// with an empty string in from json.
  /// https://e621.net/help/global_blacklist
  ///
  /// {@endtemplate}
  @override
  final String url;
  @override
  bool get hasValidUrl =>
      url.isNotEmpty &&
      (_address.isAssigned
          ? true
          : (_address.itemSafe = Uri.tryParse(url)) != null);

  final _address = LateFinal<Uri>();
  @override
  Uri get address => Uri.parse(url);

  E6Preview({
    required this.width,
    required this.height,
    required this.url,
  });
  factory E6Preview.fromJson(JsonOut json) => E6Preview(
        width: json["width"] as int,
        height: json["height"] as int,
        url: json["url"] as String? ?? "",
      );
}

class E6Sample extends E6Preview implements ISampleInfo {
  /// If the post has a sample/thumbnail or not. (True/False)
  @override
  final bool has;

  /* /// The width of the post sample.
  final int width;
  /// The height of the post sample.
  final int height; */

  /// {@macro E6Preview.url}
  ///
  /// If the post is a video, this is a preview image from the video
  @override
  /* final String url; */
  String get url => super.url;

  @override
  bool get isAVideo => extension == "webm" || extension == "mp4";

  E6Sample({
    required this.has,
    required super.width,
    required super.height,
    required super.url,
  });
  factory E6Sample.fromJson(JsonOut json) => E6Sample(
        has: json["has"] as bool,
        width: json["width"] as int,
        height: json["height"] as int,
        url: json["url"] as String? ?? "",
      );
}

class E6Score {
  /// The number of times voted up.
  final int up;

  /// A negative number representing the number of times voted down.
  final int down;

  /// The total score (up + down).
  final int total;

  E6Score({
    required this.up,
    required this.down,
    required this.total,
  });
  factory E6Score.fromJson(JsonOut json) => E6Score(
        up: json["up"] as int,
        down: json["down"] as int,
        total: json["total"] as int,
      );

  Map<String, dynamic> toJson() => {
        "up": up,
        "down": down,
        "total": total,
      };
}

class E6PostTags {
  /// A JSON array of all the general tags on the post.
  final List<String> general;

  /// A JSON array of all the species tags on the post.
  final List<String> species;

  /// A JSON array of all the character tags on the post.
  final List<String> character;

  /// A JSON array of all the artist tags on the post.
  final List<String> artist;

  /// A JSON array of all the invalid tags on the post.
  final List<String> invalid;

  /// A JSON array of all the lore tags on the post.
  final List<String> lore;

  /// A JSON array of all the meta tags on the post.
  final List<String> meta;

  // #region Undocumented
  /// A JSON array of all the copyright tags on the post.
  final List<String> copyright;
  // #endregion Undocumented

  List<String> getByCategory(TagCategory c) =>
      getByCategorySafe(c) ??
      (throw ArgumentError.value(c, "c", "Can't be TagCategory._error"));
  List<String>? getByCategorySafe(TagCategory c) => switch (c) {
        TagCategory.general => general,
        TagCategory.species => species,
        TagCategory.character => character,
        TagCategory.artist => artist,
        TagCategory.invalid => invalid,
        TagCategory.lore => lore,
        TagCategory.meta => meta,
        TagCategory.copyright => copyright,
        _ => null,
      };

  E6PostTags({
    required this.general,
    required this.species,
    required this.character,
    required this.artist,
    required this.invalid,
    required this.lore,
    required this.meta,
    required this.copyright,
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

class E6Flags {
  /// If the post is pending approval. (True/False)
  final bool pending;

  /// If the post is flagged for deletion. (True/False)
  final bool flagged;

  /// If the post has it’s notes locked. (True/False)
  final bool noteLocked;

  /// If the post’s status has been locked. (True/False)
  final bool statusLocked;

  /// If the post’s rating has been locked. (True/False)
  final bool ratingLocked;

  /// If the post has been deleted. (True/False)
  final bool deleted;

  E6Flags({
    required this.pending,
    required this.flagged,
    required this.noteLocked,
    required this.statusLocked,
    required this.ratingLocked,
    required this.deleted,
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

class E6Relationships {
  /// The ID of the post’s parent, if it has one.
  final int? parentId;

  /// If the post has child posts (True/False)
  final bool hasChildren;

  /// If the post has active child posts (True/False)
  ///
  /// J's Note: I assume "active" means not deleted
  final bool hasActiveChildren;

  /// A list of child post IDs that are linked to the post, if it has any.
  final List<String> children;

  bool get hasParent => parentId != null;

  E6Relationships({
    required this.parentId,
    required this.hasChildren,
    required this.hasActiveChildren,
    required this.children,
  });
  factory E6Relationships.fromJson(JsonOut json) => E6Relationships(
        parentId: json["parent_id"] as int?,
        hasChildren: json["has_children"] as bool,
        hasActiveChildren: json["has_active_children"] as bool,
        children: (json["children"] as List).cast<String>(),
      );
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
