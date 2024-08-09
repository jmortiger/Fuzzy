import 'dart:convert';

import 'package:fuzzy/util/util.dart';
import 'package:j_util/j_util_full.dart';

class TagDB {
  final Set<String> tagSet;
  final List<TagDBEntry /* Full */ > tags;
  final Map<String, (TagCategory, int)> tagsMap;
  final PriorityQueue<TagDBEntry /* Full */ > tagsByPopularity;
  // final List<PriorityQueue<TagDBEntry/* Full */>> tagsByFirstCharsThenPopularity;
  final CustomPriorityQueue<TagDBEntry /* Full */ > tagsByString;
  final Map<String, (int, int)> _startEndOfChar = <String, (int, int)>{};
  (int, int) getCharStartAndEnd(String character) =>
      _startEndOfChar[character[0]] ??
      (_startEndOfChar[character[0]] = (
        tagsByString.queue
            .indexWhere((element) => character[0] == element.name[0]),
        tagsByString.queue
            .lastIndexWhere((element) => character[0] == element.name[0])
      ));

  /// This will likely take awhile. Try async.
  TagDB({
    required this.tagSet,
    required this.tags,
    required this.tagsMap,
    required this.tagsByPopularity,
    // required this.tagsByFirstCharsThenPopularity,
    required this.tagsByString,
  });
  TagDB.fromEntries(List<TagDBEntryFull> entries)
      : tagSet = Set<String>.unmodifiable(
            entries.mapTo((elem, index, list) => elem.name)),
        tags = entries,
        tagsMap = Map.unmodifiable(
            {for (var e in entries) e.name: (e.category, e.postCount)}),
        tagsByPopularity = PriorityQueue(entries),
        tagsByString = CustomPriorityQueue(
            entries,
            (a, b) => a.name.compareTo(b
                .name)) /* ,
        tagsByFirstCharsThenPopularity = entries..sort((a, b) => a.name.compareTo(b.name))..reduceToType((accumulator, elem, index, list){
          
        }, ("")) */
  ;
  factory TagDB.fromCsvString(String csv) =>
      TagDB.fromEntries(((csv.split("\n")..removeAt(0))..removeLast())
          .mapAsList((e, index, list) {
        var t = e.split(",");
        if (e.contains('"')) {
          t = [
            t[0],
            e.substring(e.indexOf('"'), e.lastIndexOf('"')),
            t[t.length - 2],
            t.last
          ];
        }
        if (t.length == 5) t = [t[0], t[1] + t[2], t[3], t[4]];
        return TagDBEntryFull(
            id: int.parse(t[0]),
            name: t[1],
            category: TagCategory.values[int.parse(t[2])],
            postCount: int.parse(t[3]));
      }));
  static Future<TagDB> makeFromCsvString(String csv) async =>
      Future.microtask(() => TagDB.fromCsvString(csv));
  // JsonMap toJson() => {
  //   "id": id,
  //   "name": name,
  //   "category": category.index,
  //   "post_count": post_count,
  // };
  // factory TagDBEntry.fromJson(JsonMap json) => TagDBEntry(
  //   id: json["id"] as int,
  //   name: json["name"] as String,
  //   category: json["category"] as TagCategory,
  //   post_count: json["post_count"] as int,
  // );
}

class TagDBEntryFull extends TagDBEntry {
  final int id;

  TagDBEntryFull({
    required this.id,
    required super.name,
    required super.category,
    required super.postCount,
  });
  @override
  JsonMap toJson() => {
        "id": id,
        "name": name,
        "category": category.index,
        "post_count": postCount,
      };
  factory TagDBEntryFull.fromJson(JsonMap json) => TagDBEntryFull(
        id: json["id"] as int,
        name: json["name"] as String,
        category: json["category"] as TagCategory,
        postCount: json["post_count"] as int,
      );
}

class TagDBEntry implements Comparable<TagDBEntry> {
  final String name;
  final TagCategory category;
  final int postCount;

  TagDBEntry({
    required this.name,
    required this.category,
    required this.postCount,
  });
  JsonMap toJson() => {
        "name": name,
        "category": category.index,
        "post_count": postCount,
      };
  factory TagDBEntry.fromJson(JsonMap json) => TagDBEntry(
        name: json["name"] as String,
        category: json["category"] as TagCategory,
        postCount: json["post_count"] as int,
      );
  factory TagDBEntry.fromFull(TagDBEntryFull entry) => TagDBEntry(
        name: entry.name,
        category: entry.category,
        postCount: entry.postCount,
      );

  @override
  // int compareTo(TagDBEntry other) => other.postCount - postCount;
  int compareTo(TagDBEntry other) =>
      (other.postCount - (other.postCount % 5)) - (postCount - postCount % 5);
}

class TagSearchModel {
  final List<TagSearchEntry> tags;

  TagSearchModel({required this.tags});

  factory TagSearchModel.fromJson(JsonMap json) => TagSearchModel(
      tags: json["tags"] != null ? [] : (json as List).cast<TagSearchEntry>());

  dynamic toJson() =>
      tags.isEmpty ? {"tags": []} : json.decode(tags.toString());
}

class TagSearchEntry {
  /// <numeric tag id>,
  final int id;

  /// <tag display name>,
  final String name;

  /// <# matching visible posts>,
  final int postCount;

  /// <space-delimited list of tags>,
  final List<String> relatedTags;

  /// <ISO8601 timestamp>,
  final DateTime relatedTagsUpdatedAt;

  /// <numeric category id>,
  final TagCategory category;

  /// <boolean>,
  final bool isLocked;

  /// <ISO8601 timestamp>,
  final DateTime createdAt;

  /// <ISO8601 timestamp>
  final DateTime updatedAt;

  TagSearchEntry({
    required this.id,
    required this.name,
    required this.postCount,
    required this.relatedTags,
    required this.relatedTagsUpdatedAt,
    required this.category,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
  });
  factory TagSearchEntry.fromJson(JsonMap json) => TagSearchEntry(
        id: json["id"] as int,
        name: json["name"] as String,
        postCount: json["post_count"] as int,
        relatedTags: (json["related_tags"] as List).cast<String>(),
        relatedTagsUpdatedAt: json["related_tags_updated_at"] as DateTime,
        category: json["category"] as TagCategory,
        isLocked: json["is_locked"] as bool,
        createdAt: json["created_at"] as DateTime,
        updatedAt: json["updated_at"] as DateTime,
      );
  JsonMap toJson() => {
        "id": id,
        "name": name,
        "post_count": postCount,
        "related_tags": relatedTags,
        "related_tags_updated_at": relatedTagsUpdatedAt,
        "category": category,
        "is_locked": isLocked,
        "created_at": createdAt,
        "updated_at": updatedAt,
      };
}

/// https://e621.net/wiki_pages/11262
enum TagCategory with PrettyPrintEnum {
  /// 0
  ///
  /// This is the default type of tag, hence why it's mentioned first. If you
  /// do not specify the type of tag you want a tag to be when you create it,
  /// this is what it will become. General tags are for things that do not fall
  /// under other categories (e.g., female, chair, and sitting).
  general,

  /// 1
  ///
  /// Artist tags identify the tag as the artist. This doesn't mean the artist
  /// of the original copyrighted artwork (for example, you wouldn't use the
  /// ken_sugimori tag on a picture of Pikachu drawn by someone else).
  artist,

  /// 2; WHY
  _error,

  /// 3
  ///
  /// A copyright tag is for the program or series that a copyrighted character
  /// or some other element (such as objects) was first featured in, like
  /// Renamon in Digimon or Pikachu and Poké Balls in Pokémon. It can also be
  /// used for the company that owns a work, media franchise, or character,
  /// like Disney owns the copyright to Mickey Mouse and Nintendo owns the
  /// Mario Bros series.
  copyright,

  /// 4
  ///
  /// A character tag is a tag defining the name of a character, like
  /// pinkie_pie_(mlp) or fox_mccloud.
  character,

  /// 5
  ///
  /// A species tag describes the species of a character or being in the
  /// picture like domestic_cat, feline or domestic_dog, canine.
  species,

  /// 6
  ///
  /// The invalid type, which was technically also introduced alongside Meta
  /// and Lore in March 2020, is for tags that are not allowed on any posts,
  /// such as things that are too common and unspecific to individually tag
  /// or common tagging errors. These kinds of tags should be either fixed to
  /// add the proper intended tags or modified to be more specific. If doing so
  /// is not necessary, then the invalid tag should be removed outright. Either
  /// way, invalid tags will be the first type you see on the sidebar, even
  /// above artists, as a reminder that those tags should not be there.
  ///
  /// Previously, tags were invalidated by being aliased to either invalid_tag
  /// or invalid_color. While eSix will continue using these tags for the
  /// foreseeable future, some invalidated tags had their original aliases
  /// removed and were retyped to the invalid type to encourage better tagging
  /// over a quick "remove the invalid tag and forget it" approach.
  invalid,

  /// 7
  ///
  /// Meta (as in metadata) was introduced as one of two new tag types in March
  /// 2020. This type is for the technical side of the post's file, the post
  /// itself, or things relating to e6's own handling of a post.
  ///
  /// <details><summary>Types of meta tags</summary>
  ///
  /// * File resolution: hi_res, absurd_res, superabsurd_res, low_res, and
  /// thumbnail. Resolution meta tags are added automatically by the site,
  /// since it can read resolution metadata.
  /// * Written, drawn, painted, or typed text.
  /// * Text done in specific languages, including "real" or natural languages (e.g. english_text, japanese_text) and constructed languages (e.g. esperanto_text and fictional languages including tantalog_text from Lilo & Stitch and aurebesh_text from Star Wars).
  /// * Poorly written English text (usually deliberate): engrish.
  /// * Translation related tags: translation_request, partially_translated, translation_check, translated, hard_translated, translated_description.
  /// * Audio spoken or sung in specific languages, including "real" or natural languages (e.g. english_audio, japanese_audio) and constructed languages.
  /// * File aspect ratio: e.g. 4:3, 3:4, 16:9, 1:1, widescreen, wallpaper, 4k.
  /// * Animation length: short_playtime for under 30 seconds, and long_playtime for at least 30 seconds.
  /// * Years in which the post itself was made: e.g. 2020.
  /// * Types of media that artwork are made in, which (with the exception of mixed_media) are suffixed with _(artwork): e.g. digital_media_(artwork), 3d_(artwork), photography_(artwork), traditional_media_(artwork), pencil_(artwork).
  /// * Animation and transitions: animated, animated_png (also media format-based), pixel_animation, 3d_animation, slideshow, frame_by_frame, loop.
  /// * Audiovisual media formats: flash and webm.
  /// * Flash posts with clickable or keyboard-compatible elements: interactive.
  /// * comic for the paneled form of communication media. This also includes manga, doujinshi, and 4koma.
  /// * Request tags for when users require assistance from others to provide further information (tagme, character_request, source_request, and the aforementioned translation_request) or if they want a censored post to have its censorship removed (uncensor_request).
  /// * Posts with incorrect or improper metadata in the sidebar: bad_metadata.
  /// * Posts that are missing a sample version of an image or whose sample image is broken: missing_sample.
  /// * How colors, color palettes, and contrasts are used in a post: e.g. restricted_palette, monochrome, greyscale, black_and_white, sepia, dark_theme, light_theme, blue_theme, blue_and_white, colorful, spot_color, high_contrast, color_contrast.
  /// * Images that are suitable for user avatars: icon.
  /// * Portrait tags featuring a single character's likeness: headshot_portrait, bust_portrait, half-length_portrait, three-quarter_portrait, full-length_portrait.
  /// * Posts edited by someone other than the artist: edit, cropped, censored, uncensored, nude_edit, color_edit.
  /// * Obviously doctored images: shopped, photo_manipulation, photomorph.
  /// * Shading, lines, and detail: detailed, colored, flat_colors, guide_lines, line_art, lineless_art, partially_colored, shaded, cel_shaded, sketch, colored_sketch, unfinished.
  /// * Audio (or lack thereof) in Flash and WebM posts: sound and no_sound.
  /// * Stories tied to posts: story, story_in_description, story_at_source.
  /// * Posts with sources that contain a different version of said post: alternate_version_at_source, better_version_at_source, smaller_version_at_source.
  /// * Posts with technical visual flaws, intentional or unintentional: compression_artifacts and aliasing.
  /// * Posts with at least 150 tags: tag_panic.
  /// * Watermarks: watermark, distracting_watermark, 3rd_party_watermark.
  /// * An artist's signature.
  /// * A web link or URL.</details>
  ///
  /// Note that there are also four meta tags that are typed as artist tags instead:
  ///
  /// * epilepsy_warning for posts containing flashing lights that could trigger epileptic seizures.
  /// * jumpscare_warning for animated and Flash posts containing shocking imagery and/or sounds that can catch a viewer off-guard.
  /// * audio_warning for loud, deafening audio in Flash and WebM posts
  /// * unknown_artist_signature for posts in which the artist isn't known but a signature is on it.
  /// * third-party edit for posts edited by someone other than the original artist(s).
  ///
  /// The first three are deliberately typed as such because the bright orange
  /// color warns users about the potential dangers of those posts. The fourth
  /// is to encourage members to try to identify artists by their signatures
  /// (especially since unknown_artist is already an artist tag anyway). The
  /// fifth is because the editor may have edited enough of the post that it
  /// can be seen as derivative art, although it also helps us keep track of
  /// edits that would violate the conditions of artists who don't allow edits
  /// of their works (see conditional_dnp).
  meta,

  /// 8
  ///
  /// This is for providing and correcting specific outside information (not
  /// covered by copyright or character) when tag what you see otherwise cannot
  /// provide such. These tags are all suffixed _(lore), and only admins can
  /// introduce new lore tags. [Read more](
  /// https://e621.net/wiki_pages/show_or_new?title=e621%3Alore_tags).
  lore;

  bool get isTrueCategory => this != _error;
  bool get isValidCategory => this != _error && this != invalid;

  dynamic toJson() => index.toString();
  factory TagCategory.fromJson(dynamic json) =>
      switch (int.parse(json as String)) {
        0 => TagCategory.general,
        1 => TagCategory.artist,
        2 => TagCategory._error,
        3 => TagCategory.copyright,
        4 => TagCategory.character,
        5 => TagCategory.species,
        6 => TagCategory.invalid,
        7 => TagCategory.meta,
        8 => TagCategory.lore,
        _ => throw UnsupportedError("type not supported"),
      };
}
