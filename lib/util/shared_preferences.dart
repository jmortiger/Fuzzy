import 'package:fuzzy/util/util.dart' show TypeException;
import 'package:j_util/j_util_full.dart' show Iterators, LazyInitializer;
import 'package:shared_preferences/shared_preferences.dart';

final pref = LazyInitializer(SharedPreferences.getInstance);

// #region Remove
Future<bool>? removeFromPrefSync(
  Iterable<String> keys, [
  SharedPreferences? prefInst,
]) =>
    (prefInst ??= pref.$Safe) == null
        ? null
        : Future.wait(keys.map((e) => prefInst!.remove(e))).then((val) =>
            val.foldUntil<bool>(true, (p, e, _, __) => p && e,
                breakIfTrue: (p, _, __, ___) => !p));
Future<bool> removeFromPref(Iterable<String> keys) =>
    pref.getItemAsync().then((v) => removeFromPrefSync(keys, v)!);
// #endregion Remove

// #region Write
Future<bool>? writeToPrefSync(
  Map<String, dynamic> map, [
  SharedPreferences? prefInst,
]) {
  if ((prefInst ??= pref.$Safe) == null) return null;
  prefInst!;
  final success = <Future<bool>>[];
  for (final el in map.entries) {
    switch (el) {
      case MapEntry(key: String _, value: Null _):
        break;
      case MapEntry(key: String key, value: String value):
        success.add(prefInst.setString(key, value));
        break;
      case MapEntry(key: String key, value: bool value):
        success.add(prefInst.setBool(key, value));
        break;
      case MapEntry(key: String key, value: int value):
        success.add(prefInst.setInt(key, value));
        break;
      case MapEntry(key: String key, value: double value):
        success.add(prefInst.setDouble(key, value));
        break;
      case MapEntry(key: String key, value: List value):
        if (value.isEmpty) {
          success.add(prefInst.setStringList(key, []));
          break;
        }
        switch (value) {
          case List<String> value:
            success.add(prefInst.setStringList(key, value));
            break;
          case List<bool> _:
          case List<int> _:
          case List<double> _:
            success.add(
                prefInst.setStringList(key, value.map((e) => "$e").toList()));
            break;
          default:
            throw UnsupportedError(
                "${value.runtimeType} of $key not supported");
        }
        break;
      case MapEntry(key: String key, value: dynamic value):
        throw UnsupportedError("${value.runtimeType} of $key not supported");
    }
  }
  return Future.wait(success).then((val) => val.foldUntil<bool>(
      true, (p, e, _, __) => p && e,
      breakIfTrue: (p, _, __, ___) => !p));
}

Future<bool> writeToPref(Map<String, dynamic> map) =>
    pref.getItemAsync().then((v) => writeToPrefSync(map, v)!);
// #endregion Write

const subItemDelimiter = '.', _typeSuffix = "!TYPE";
// #region Load
Map<String, dynamic>? loadJsonFromPrefWithTypeMapSync(
  Map<String, String> typeMap, {
  SharedPreferences? prefInst,
  String separator = subItemDelimiter,
  String? prefix,
  String typeSuffix = _typeSuffix,
  bool failIfNull = false,
}) {
  if ((prefInst ??= pref.$Safe) == null) return null;
  prefInst!;
  final data = <String, dynamic>{},
      typeRE = RegExp(
          "^.*(?:(?=${RegExp.escape(typeSuffix)}\$)|(?<!${RegExp.escape(typeSuffix)})(?=\$))"),
      prefixRE = prefix != null
          ? RegExp("(?<=^${RegExp.escape(prefix)}).*\$")
          : RegExp(r"^.*$");
  T? fail<T>(String key, String value) =>
      throw UnsupportedError("$value of $key not supported");
  T? valueNullCheck<T>(String key, String value, T? v) =>
      v ??
      (failIfNull && !value.endsWith("?") && value != "Null"
          ? throw StateError("$value of $key doesn't allow a null value")
          : v);
  List<T>? parseList<T>(String key, T Function(String) parse) =>
      prefInst!.getStringList(key)?.map((e) => parse(e)).toList();
  List<T?>? tryParseList<T>(String key, T Function(String) parse) => prefInst!
      .getStringList(key)
      ?.map((e) => e == "null" ? null : parse(e))
      .toList();
  for (var el in typeMap.entries) {
    el = MapEntry(typeRE.stringMatch(el.key)!, el.value);
    final kSplit = prefixRE.stringMatch(el.key)!.split(subItemDelimiter);
    var d = data;
    for (final e in kSplit.take(kSplit.length - 1)) {
      d = d[e] ??= <String, dynamic>{};
    }
    d[kSplit.last] = switch (el) {
      MapEntry(key: String _, value: "Null") => null,
      MapEntry(key: String key, value: "String" || "String?") =>
        prefInst.getString(key),
      MapEntry(key: String key, value: "bool" || "bool?") =>
        prefInst.getBool(key),
      MapEntry(key: String key, value: "int" || "int?") => prefInst.getInt(key),
      MapEntry(key: String key, value: "double" || "double?") =>
        prefInst.getDouble(key),
      MapEntry(key: String key, value: String value) => switch (
            RegExp(r"^List<(.*)>\??$").firstMatch(value)?.group(1) ?? value) {
          "String" => prefInst.getStringList(key),
          "String?" => tryParseList(key, (e) => e),
          "bool" => parseList(key, bool.parse),
          "bool?" => tryParseList(key, bool.parse),
          "int" => parseList(key, int.parse),
          "int?" => tryParseList(key, int.parse),
          "double" => parseList(key, double.parse),
          "double?" => tryParseList(key, double.parse),
          String value => fail(key, value),
        },
      // MapEntry(key: String key, value: String value) => fail(key, value),
    };
    valueNullCheck(el.key, el.value, d[kSplit.last]);
  }
  return data;
}

Future<Map<String, dynamic>?> loadJsonFromPrefWithTypeMap(
  Map<String, String> typeMap, {
  String separator = subItemDelimiter,
  String? prefix,
  String typeSuffix = _typeSuffix,
  bool failIfNull = false,
}) async =>
    loadJsonFromPrefWithTypeMapSync(
      typeMap,
      prefInst: await pref.getItem(),
      failIfNull: failIfNull,
      prefix: prefix,
      separator: separator,
      typeSuffix: typeSuffix,
    );

/// Assumes all type data is stored in preferences under the values in [keys].
Map<String, dynamic>? loadJsonFromPrefWithKeysSync(
  Iterable<String> keys, {
  SharedPreferences? prefInst,
  String separator = subItemDelimiter,
  String? prefix,
  String typeSuffix = _typeSuffix,
  bool failIfNull = false,
}) =>
    (prefInst ??= pref.$Safe) == null
        ? null
        : loadJsonFromPrefWithTypeMapSync(
            keys.fold({}, (p, e) => p..addAll({e: prefInst!.getString(e)!})),
            prefInst: prefInst,
            failIfNull: failIfNull,
            prefix: prefix,
            typeSuffix: typeSuffix,
            separator: separator,
          );
Future<Map<String, dynamic>?> loadJsonFromPrefWithKeys(
  Iterable<String> keys, {
  String separator = subItemDelimiter,
  String? prefix,
  String typeSuffix = _typeSuffix,
  bool failIfNull = false,
}) async =>
    loadJsonFromPrefWithKeysSync(
      keys,
      prefInst: await pref.getItem(),
      failIfNull: failIfNull,
      prefix: prefix,
      separator: separator,
      typeSuffix: typeSuffix,
    );
// Map<String, dynamic>? loadJsonFromPrefSync(Map<String, String> typeMap,
//     [SharedPreferences? prefInst]) {
//   if ((prefInst ??= pref.$Safe) == null) return null;
//   prefInst!;
//   final data = <String, dynamic>{};
//   for (final el in typeMap.entries) {
//     switch (el) {
//       case MapEntry(key: String key, value: String _):
//         data[key] = prefInst.getString(key);
//         break;
//       case MapEntry(key: String key, value: bool _):
//         data[key] = prefInst.getBool(key);
//         break;
//       case MapEntry(key: String key, value: int _):
//         data[key] = prefInst.getInt(key);
//         break;
//       case MapEntry(key: String key, value: double _):
//         data[key] = prefInst.getDouble(key);
//         break;
//       case MapEntry(key: String key, value: List value):
//         switch (value) {
//           case List<String> _:
//             data[key] = prefInst.getStringList(key);
//             break;
//           case List<bool> _:
//             data[key] =
//                 prefInst.getStringList(key)?.map((e) => bool.parse(e)).toList();
//           case List<int> _:
//             data[key] =
//                 prefInst.getStringList(key)?.map((e) => int.parse(e)).toList();
//           case List<double> _:
//             data[key] = prefInst
//                 .getStringList(key)
//                 ?.map((e) => double.parse(e))
//                 .toList();
//             break;
//           default:
//             throw UnsupportedError(
//                 "${value.runtimeType} of $key not supported");
//         }
//         break;
//       case MapEntry(key: String key, value: dynamic value):
//         throw UnsupportedError("${value.runtimeType} of $key not supported");
//     }
//   }
//   return AppSettings.fromPrefMap(data);
// }

// #endregion Load
/// Doesn't mutate entries in [map], does mutate [map].
Map<String, dynamic> pullStringMapsDownRecursively(
  Map<String, dynamic> map, [
  String separator = subItemDelimiter,
]) {
  final waitList = <String, dynamic>{}, toRemove = <String>[];
  var recurse = false;
  for (var e in map.entries) {
    if (e.value is Map<String, dynamic>) {
      recurse = true;
      toRemove.add(e.key);
      waitList.addAll((e.value as Map<String, dynamic>)
          .map((key, value) => MapEntry("${e.key}$separator$key", value)));
    }
  }
  if (recurse) pullStringMapsDownRecursively(waitList);
  map.addAll(waitList);
  toRemove.forEach(map.remove);
  return map;
}

/// Include separator in [prefix].
///
/// Doesn't mutate [json].
Map<String, dynamic> fromJsonMapToPrefMap(
  Map<String, dynamic> json,
  String prefix,
) =>
    pullStringMapsDownRecursively(json.map((k, v) => MapEntry("$prefix$k", v)));

/// If [assertValidity], throw a [TypeError].
///
/// Doesn't mutate [json].
Map<String, dynamic> fromJsonMapToPrefTypedMap(
  Map<String, dynamic> json,
  String prefix, {
  bool assertValidity = false,
}) {
  final t = fromJsonMapToPrefMap(json, prefix);
  return t..addAll(makePrefTypeMap(t));
}

/// If [assertValidity], throw a [TypeError] if any value is not one of the accepted types.
Map<String, String> makePrefTypeMap(
  Map<String, dynamic> map, {
  bool appendSuffix = true,
  bool assertValidity = false,
  String prefix = "",
}) =>
    {
      for (final e in map.entries)
        "$prefix${e.key}${appendSuffix ? _typeSuffix : ""}": assertValidity &&
                switch (e.value) {
                  String _ ||
                  String? _ ||
                  bool _ ||
                  bool? _ ||
                  int _ ||
                  int? _ ||
                  double _ ||
                  double? _ ||
                  List<String> _ ||
                  List<String>? _ ||
                  List<String?> _ ||
                  List<String?>? _ ||
                  List<bool> _ ||
                  List<bool>? _ ||
                  List<bool?> _ ||
                  List<bool?>? _ ||
                  List<int> _ ||
                  List<int>? _ ||
                  List<int?> _ ||
                  List<int?>? _ ||
                  List<double> _ ||
                  List<double>? _ ||
                  List<double?> _ ||
                  List<double?>? _ ||
                  Null _ =>
                    false,
                  _ => true
                }
            ? throw TypeException.fromTypeStrings("${e.value.runtimeType}",
                valid: const [
                    "String",
                    "String?",
                    "bool",
                    "bool?",
                    "int",
                    "int?",
                    "double",
                    "double?",
                    "List<String>",
                    "List<String>?",
                    "List<String?>",
                    "List<String?>?",
                    "List<bool>",
                    "List<bool>?",
                    "List<bool?>",
                    "List<bool?>?",
                    "List<int>",
                    "List<int>?",
                    "List<int?>",
                    "List<int?>?",
                    "List<double>",
                    "List<double>?",
                    "List<double?>",
                    "List<double?>?",
                    "Null",
                  ])
            : e.value.runtimeType.toString()
    };

/* T? parsePrefStoredValue<T>(String? value, bool isRoot, [T Function(dynamic)? fromJson]) {
  if (value == null) return null;
  switch (T) {
    case const (String):
      return value as T?;
    case const (bool):
      return bool.parse(value) as T?;
    case const (int):
      return int.parse(value) as T?;
    case const (double):
      return double.parse(value) as T?;
    case _ when [] is T:
      switch (T) {
        case const (List<String>):
          return v.getStringList(key) as T?;
        case const (List<int>):
          return v.getStringList(key).map((e)=>) as T?;
        case const (List<double>):
          return v.getStringList(key).map((e)=>) as T?;
        case const (List<Enum>):
          return v.getStringList(key).map((e)=>) as T?;
        default:
          return v.getStringList(key) as T?;
      }
    case const (Iterable):
      switch (value) {
        case const (Iterable<String>):
          return v.getStringList(key.toList(growable: false)) as T?;
        case const (Iterable<int>):
        case const (Iterable<double>):
        case const (Iterable<Enum>):
          return v.getStringList(key) as T?;
        default:
          return v.getStringList(
              key.map((e) => "$e").toList(growable: false)) as T?;
      }
    default:
      return v.getString(key.toString()) as T?;
  }
}
int? parsePrefStoredValueInt(String value, bool isRoot, [int Function(dynamic)? fromJson]) {
  return fromJson?.call(value) ?? int.parse(value);
}
Future<bool> setValue<T>(String key, T value,
    [String lengthSuffix = ".length"]) async {
  final v = await pref.getItem();
  switch (value) {
    case String value:
      return v.setString(key, value);
    case bool value:
      return v.setBool(key, value);
    case int value:
      return v.setInt(key, value);
    case double value:
      return v.setDouble(key, value);
    case List value:
      if (value.isEmpty) {
        return v.setStringList(key, []);
      }
      switch (value) {
        case List<String> value:
          return v.setStringList(key, value);
        case List<int> _:
        case List<double> _:
        case List<Enum> _:
          return v.setStringList(key, value.map((e) => "$e").toList());
        default:
          return v.setStringList(key, value.map((e) => "$e").toList());
      }
    case Iterable value:
      if (value.isEmpty) {
        return v.setStringList(key, []);
      }
      switch (value) {
        case Iterable<String> value:
          return v.setStringList(key, value.toList(growable: false));
        case Iterable<int> _:
        case Iterable<double> _:
        case Iterable<Enum> _:
          return v.setStringList(
              key, value.map((e) => "$e").toList(growable: false));
        default:
          return v.setStringList(
              key, value.map((e) => "$e").toList(growable: false));
      }
    default:
      return v.setString(key, value.toString());
  }
}

Future<T?> getValue<T>(String key, [, String lengthSuffix = ".length"]) async {
  final v = await pref.getItem();
  switch (T) {
    case const (String):
      return v.getString(key) as T?;
    case const (bool):
      return v.getBool(key) as T?;
    case const (int):
      return v.getInt(key) as T?;
    case const (double):
      return v.getDouble(key) as T?;
    case _ when [] is T:
      switch (T) {
        case const (List<String>):
          return v.getStringList(key) as T?;
        case const (List<int>):
          return v.getStringList(key).map((e)=>) as T?;
        case const (List<double>):
          return v.getStringList(key).map((e)=>) as T?;
        case const (List<Enum>):
          return v.getStringList(key).map((e)=>) as T?;
        default:
          return v.getStringList(key) as T?;
      }
    case const (Iterable):
      switch (value) {
        case const (Iterable<String>):
          return v.getStringList(key.toList(growable: false)) as T?;
        case const (Iterable<int>):
        case const (Iterable<double>):
        case const (Iterable<Enum>):
          return v.getStringList(key) as T?;
        default:
          return v.getStringList(
              key.map((e) => "$e").toList(growable: false)) as T?;
      }
    default:
      return v.getString(key.toString()) as T?;
  }
} */
