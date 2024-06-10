//https://pypi.org/project/faapi/3.11.4/
//https://www.furaffinity.net/robots.txt
//https://furaffinity-api.herokuapp.com/docs
import 'package:fuzzy/util/util.dart';

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
