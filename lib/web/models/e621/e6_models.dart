import 'package:j_util/j_util_full.dart';

import '../image_listing.dart';

typedef JsonOut = Map<String, dynamic>;

final class E6Posts {
  final _postList = <E6PostResponse>[];
  final Late<int> _postCapacity = Late();
  int get capacity => _postCapacity.itemSafe ?? -1;
  int get count => _postList.length;
  final Iterator<E6PostResponse> _postListIterator;
  E6PostResponse? tryGet(
    int index, {
    bool checkForValidFileUrl = true,
  }) {
    try {
      return (this[index].file.url != "") ? this[index] : this[index + 1];
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
      if (mn == false) {
        _postCapacity.item = _postList.length;
      }
    }
    return _postList[index];
  }

  final Iterable<E6PostResponse> posts;

  E6Posts({required this.posts}) : _postListIterator = posts.iterator;
  factory E6Posts.fromJson(JsonOut json) => E6Posts(
      posts:
          (json["posts"] as Iterable).map((e) => E6PostResponse.fromJson(e)));
}

final class E6PostResponse implements ImageListing {
  @override
  Uri get imageAddress => Uri.parse(file.url);
  @override
  String get imageUrl => file.url;
  @override
  Uri get imagePreviewAddress => Uri.parse(preview.url);
  @override
  String get imagePreviewUrl => preview.url;
  @override
  int get imageWidth => file.width;
  @override
  int get imageHeight => file.height;
  @override
  int get imagePreviewWidth => preview.width;
  @override
  int get imagePreviewHeight => preview.height;

  // #region Json Fields
  /// The ID number of the post.
  final int id;

  /// The time the post was created in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  final String created_at;

  /// The time the post was last updated in the format of YYYY-MM-DDTHH:MM:SS.MS+00:00.
  final String updated_at;

  /// (array group)
  final E6FileResponse file;

  /// (array group)
  final E6Preview preview;

  /// (array group)
  final E6Sample sample;

  /// (array group)
  final E6Score score;

  /// (array group)
  final E6PostTags tags;

  /// A JSON array of tags that are locked on the post.
  final List<String> locked_tags;

  /// An ID that increases for every post alteration on E6 (explained below)
  final int change_seq;

  /// (array group)
  final E6Flags flags;

  /// The post’s rating. Either s, q or e.
  final String rating;

  /// How many people have favorited the post.
  final int fav_count;

  /// The source field of the post.
  final List<String> sources;

  /// An array of Pool IDs that the post is a part of.
  final List<String> pools;

  /// (array group)
  final E6Relationships relationships;

  /// The ID of the user that approved the post, if available.
  final int? approver_id;

  /// The ID of the user that uploaded the post.
  final int uploader_id;

  /// The post’s description.
  final String description;

  /// The count of comments on the post.
  final int comment_count;

  /// If provided auth credentials, will return if the authenticated user has favorited the post or not.
  final bool? is_favorited;
  // #endregion Json Fields

  E6PostResponse({
    required this.id,
    required this.created_at,
    required this.updated_at,
    required this.file,
    required this.preview,
    required this.sample,
    required this.score,
    required this.tags,
    required this.locked_tags,
    required this.change_seq,
    required this.flags,
    required this.rating,
    required this.fav_count,
    required this.sources,
    required this.pools,
    required this.relationships,
    required this.approver_id,
    required this.uploader_id,
    required this.description,
    required this.comment_count,
    required this.is_favorited,
  });

  factory E6PostResponse.fromJson(JsonOut json) => E6PostResponse(
        id: json["id"] as int,
        created_at: json["created_at"] as String,
        updated_at: json["updated_at"] as String,
        file: E6FileResponse.fromJson(json["file"] as JsonOut),
        preview: E6Preview.fromJson(json["preview"] as JsonOut),
        sample: E6Sample.fromJson(json["sample"] as JsonOut),
        score: E6Score.fromJson(json["score"] as JsonOut),
        tags: E6PostTags.fromJson(json["tags"] as JsonOut),
        locked_tags: (json["locked_tags"] as List).cast<String>(),
        change_seq: json["change_seq"] as int,
        flags: E6Flags.fromJson(json["flags"] as JsonOut),
        rating: json["rating"] as String,
        fav_count: json["fav_count"] as int,
        sources: (json["sources"] as List).cast<String>(),
        pools: (json["pools"] as List).cast<String>(),
        relationships:
            E6Relationships.fromJson(json["relationships"] as JsonOut),
        approver_id: json["approver_id"] as int?,
        uploader_id: json["uploader_id"] as int,
        description: json["description"] as String,
        comment_count: json["comment_count"] as int,
        is_favorited: json["is_favorited"] as bool?,
      );
}

class E6Relationships {
  /// The ID of the post’s parent, if it has one.
  final int? parent_id;

  /// If the post has child posts (True/False)
  final bool has_children;

  /// If the post has active child posts (True/False)
  ///
  /// J's Note: I assume "active" means not deleted
  final bool has_active_children;

  /// A list of child post IDs that are linked to the post, if it has any.
  final List<String> children;

  E6Relationships({
    required this.parent_id,
    required this.has_children,
    required this.has_active_children,
    required this.children,
  });
  factory E6Relationships.fromJson(JsonOut json) => E6Relationships(
        parent_id: json["parent_id"] as int?,
        has_children: json["has_children"] as bool,
        has_active_children: json["has_active_children"] as bool,
        children: (json["children"] as List).cast<String>(),
      );
}

class E6Flags {
  /// If the post is pending approval. (True/False)
  final bool pending;

  /// If the post is flagged for deletion. (True/False)
  final bool flagged;

  /// If the post has it’s notes locked. (True/False)
  final bool note_locked;

  /// If the post’s status has been locked. (True/False)
  final bool status_locked;

  /// If the post’s rating has been locked. (True/False)
  final bool rating_locked;

  /// If the post has been deleted. (True/False)
  final bool deleted;

  E6Flags({
    required this.pending,
    required this.flagged,
    required this.note_locked,
    required this.status_locked,
    required this.rating_locked,
    required this.deleted,
  });
  factory E6Flags.fromJson(JsonOut json) => E6Flags(
        pending: json["pending"] as bool,
        flagged: json["flagged"] as bool,
        note_locked: json["note_locked"] as bool,
        status_locked: json["status_locked"] as bool,
        rating_locked: json["rating_locked"] as bool,
        deleted: json["deleted"] as bool,
      );
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

  E6PostTags({
    required this.general,
    required this.species,
    required this.character,
    required this.artist,
    required this.invalid,
    required this.lore,
    required this.meta,
  });
  factory E6PostTags.fromJson(JsonOut json) => E6PostTags(
        general: (json["general"] as List).cast<String>(),
        species: (json["species"] as List).cast<String>(),
        character: (json["character"] as List).cast<String>(),
        artist: (json["artist"] as List).cast<String>(),
        invalid: (json["invalid"] as List).cast<String>(),
        lore: (json["lore"] as List).cast<String>(),
        meta: (json["meta"] as List).cast<String>(),
      );
}

class E6FileResponse {
  /// The width of the post.
  final int width;

  /// The height of the post.
  final int height;

  /// The file’s extension.
  final String ext;

  /// The size of the file in bytes.
  final int size;

  /// The md5 of the file.
  final String md5;

  /// The URL where the file is hosted on E6
  final String url;

  E6FileResponse({
    required this.width,
    required this.height,
    required this.ext,
    required this.size,
    required this.md5,
    required this.url,
  });
  factory E6FileResponse.fromJson(JsonOut json) => E6FileResponse(
        width: json["width"] as int,
        height: json["height"] as int,
        ext: json["ext"] as String,
        size: json["size"] as int,
        md5: json["md5"] as String,
        url: json["url"] as String? ?? "", // TODO: THIS CAN BE NULL???
      );
}

class E6Preview {
  /// The width of the post preview.
  final int width;

  /// The height of the post preview.
  final int height;

  /// The URL where the preview file is hosted on E6
  final String url;

  E6Preview({
    required this.width,
    required this.height,
    required this.url,
  });
  factory E6Preview.fromJson(JsonOut json) => E6Preview(
        width: json["width"] as int,
        height: json["height"] as int,
        url: json["url"] as String,
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
}

class E6Sample {
  /// If the post has a sample/thumbnail or not. (True/False)
  final bool has;

  /// The width of the post sample.
  final int width;

  /// The height of the post sample.
  final int height;

  /// The URL where the sample file is hosted on E6.
  final String url;

  E6Sample({
    required this.has,
    required this.width,
    required this.height,
    required this.url,
  });
  factory E6Sample.fromJson(JsonOut json) => E6Sample(
        has: json["has"] as bool,
        width: json["width"] as int,
        height: json["height"] as int,
        url: json["url"] as String,
      );
}
