// https://e621.net/help/cheatsheet
import 'package:j_util/j_util.dart';

class SearchHelper {}

enum Order {
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
  static const prefix = "order:";
  final String tagSuffix;

  String get searchText => "$prefix$tagSuffix";

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
