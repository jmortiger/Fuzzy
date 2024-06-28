//https://pypi.org/project/faapi/3.11.4/
//https://www.furaffinity.net/robots.txt
//https://furaffinity-api.herokuapp.com/docs
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/models/image_listing.dart';
import 'package:j_util/fa.dart' as fa;
import 'package:j_util/j_util_full.dart';

class Cookie {
  final String name;
  final String value;

  Cookie(this.name, this.value);
}

class CookieJar {
  static String aValue = "";
  static String bValue = "";
  static Map<String, String> get generateA => {"name": "a", "value": aValue};
  static String get generateAString => '{"name": "a", "value": $aValue}';
  static Map<String, String> get generateB => {"name": "b", "value": bValue};
  static String get generateBString => '{"name": "b", "value": $bValue}';
  static List<Map<String, String>> get generateCookies =>
      [generateA, generateB];
  static String get generateCookiesString => "[$generateA, $generateB]";
}

class RequestBody {
  final String bodyType = "application/json";
  final List<Map<String, String>> cookies;
  final bool bbcode;

  RequestBody({required this.cookies, this.bbcode = false});

  factory RequestBody.fromJson(JsonMap json) => RequestBody(
        cookies: (json["cookies"] as List).cast<Map<String, String>>(),
        bbcode: (json["bbcode"] as bool?) ?? false,
      );

  JsonMap toJson() => {
        "cookies": cookies,
        "bbcode": bbcode,
      };
}

class Post extends fa.Post implements PostListingBare {
  @override
  final TagData tagData;
  Post({
    required super.id,
    required super.title,
    required super.author,
    required super.date,
    required super.tags,
    required super.category,
    required super.species,
    required super.gender,
    required super.rating,
    required super.type,
    required super.stats,
    required super.description,
    required super.footer,
    required super.mentions,
    required super.folder,
    required super.userFolders,
    required super.fileUrl,
    required super.thumbnailUrl,
    required super.comments,
    required super.prev,
    required super.next,
    required super.favorite,
    required super.favoriteToggleLink,
  }) : tagData = TagData(general: tags, species: [species]),
        preview = ImageInfoBare(url: thumbnailUrl),
        file = ImageInfoBare(url: fileUrl);

  @override
  DateTime get createdAt => super.date;

  @override
  ImageInfoBare file;

  @override
  bool get isFavorited => favorite;

  @override
  final ImageInfoBare preview;

  @override
  List<String> get tagList => tagData.all;
}

class TagData implements ITagData {
  @override
  final List<String> general;

  @override
  final List<String> species;

  List<String> get all => [...general, ...species];

  TagData({required this.general, required this.species});
}

class ImageInfoBare implements IImageInfoBare {
  final _address = LateFinal<Uri>();
  @override
  Uri get address =>
      _address.isAssigned ? _address.$ : _address.itemSafe = Uri.parse(url);

  @override
  String get extension => url.substring(url.lastIndexOf(".") + 1);

  @override
  bool get hasValidUrl => IImageInfoBare.hasValidUrlImpl(this);

  @override
  bool get isAVideo => IImageInfoBare.isAVideoImpl(this);

  @override
  final String url;

  ImageInfoBare({required this.url});
}
