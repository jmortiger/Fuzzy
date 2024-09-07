import 'dart:collection';
import 'package:flutter/foundation.dart';

/// TODO: Move to package
class MapNotifier<K, V> extends ChangeNotifier with MapMixin<K, V> {
  final Map<K, V> _map;

  MapNotifier() : _map = <K, V>{};
  MapNotifier.from(Map map) : _map = Map<K, V>.from(map);
  MapNotifier.fromEntries(Iterable<MapEntry<K, V>> entries)
      : _map = Map<K, V>.fromEntries(entries);
  MapNotifier.fromIterable(
    Iterable iterable, {
    K Function(dynamic element)? key,
    V Function(dynamic element)? value,
  }) : _map = Map<K, V>.fromIterable(iterable, key: key, value: value);
  MapNotifier.fromIterables(Iterable<K> keys, Iterable<V> values)
      : _map = Map<K, V>.fromIterables(keys, values);
  MapNotifier.identity() : _map = Map<K, V>.identity();
  MapNotifier.of(Map<K, V> map) : _map = Map<K, V>.of(map);
  MapNotifier.unmodifiable(Map map) : _map = Map<K, V>.unmodifiable(map);

  @override
  V? operator [](Object? key) => _map[key];

  @override
  void operator []=(K key, V value) {
    _map[key] = value;
    notifyListeners();
  }

  @override
  void clear() {
    _map.clear();
    notifyListeners();
  }

  @override
  Iterable<K> get keys => _map.keys;

  @override
  V? remove(Object? key, [bool checkForKey = true]) {
    V? doIt() {
      final r = _map.remove(key);
      notifyListeners();
      return r;
    }

    if (checkForKey) {
      return _map.containsKey(key) ? doIt() : null;
    }
    return doIt();
  }
}
