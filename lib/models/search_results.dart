import 'package:flutter/foundation.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart' show E6PostResponse;
import 'package:j_util/j_util_full.dart';

import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/log_management.dart' show SymbolName;

class SearchResultsNotifier with ChangeNotifier {
  // ignore: unnecessary_late
  static late final logger =
      lm.generateLogger((#SearchResultsNotifier).name).logger;
  SearchResultsNotifier({
    Set<int>? selectedIndices,
    Set<int>? selectedPostIds,
  })  : _selectedIndices = selectedIndices == null
            ? SetNotifier<int>()
            : selectedIndices is SetNotifier<int>
                ? selectedIndices
                : SetNotifier<int>.from(selectedIndices),
        _selectedPostIds = selectedPostIds == null
            ? SetNotifier<int>()
            : selectedPostIds is SetNotifier<int>
                ? selectedPostIds
                : SetNotifier<int>.from(selectedPostIds);
  SetNotifier<int> _selectedIndices;
  Set<int> get selectedIndices => _selectedIndices;
  set selectedIndices(Set<int> value) {
    logger.finer("selectedIndices assignment");
    if (setEquals(_selectedIndices, value)) {
      logger.finest("New Set != Old Set, assigning and notifying listeners");
      // _selectedIndices =
      //     value is SetNotifier<int> ? value : SetNotifier<int>.from(value);
      _selectedIndices.clear();
      _selectedIndices.addAll(value);
      notifyListeners();
    } else {
      logger
          .finest("New Set == Old Set, not assigning nor notifying listeners");
    }
  }

  SetNotifier<int> _selectedPostIds /*  = <int>{} */;
  Set<int> get selectedPostIds => _selectedPostIds;
  set selectedPostIds(Set<int> value) {
    logger.finer("selectedPostIds assignment");
    if (!setEquals(_selectedPostIds, value)) {
      logger.finest("New Set != Old Set, assigning and notifying listeners");
      // _selectedPostIds =
      //     value is SetNotifier<int> ? value : SetNotifier<int>.from(value);
      _selectedPostIds.clear();
      _selectedPostIds.addAll(value);
      notifyListeners();
    } else {
      logger
          .finest("New Set == Old Set, not assigning nor notifying listeners");
    }
  }

  bool get areAnySelected => _selectedIndices.isNotEmpty;
  bool getIsSelected(int index) => _selectedIndices.contains(index);
  bool getIsPostSelected(int id) => _selectedPostIds.contains(id);

  /// true if it's been added, false if it's been removed
  bool toggleSelection({
    required int index,
    int? postId,
    bool resolveDesync = true,
    bool throwOnDesync = false,
  }) {
    logger.fine("toggleSelection: ");
    logger.finer("\tindices: ${selectedIndices.toSet()}"
        "\tposts: ${selectedPostIds.toSet()}");
    if (getIsSelected(index) && (postId == null || getIsPostSelected(postId))) {
      _selectedPostIds.remove(postId ?? -1);
      _selectedIndices.remove(index);
      logger.finer("After: "
          "\tindices: ${selectedIndices.toSet()}"
          "\tposts: ${selectedPostIds.toSet()}");
      notifyListeners();
      return false;
    } else if (!getIsSelected(index) &&
        (postId == null || !getIsPostSelected(postId))) {
      if (postId != null) {
        _selectedPostIds.add(postId);
      }
      _selectedIndices.add(index);
      logger.finer("After: "
          "\tindices: ${selectedIndices.toSet()}"
          "\tposts: ${selectedPostIds.toSet()}");
      notifyListeners();
      return true;
    } else {
      if (resolveDesync) {
        logger.severe("Selected indices and posts desynced, resolving");
        _selectedIndices.clear();
        _selectedPostIds.clear();
        notifyListeners();
      }
      logger.severe("Selected indices and posts desynced");
      if (throwOnDesync) {
        throw StateError("Selected indices and posts desynced");
      } else {
        return getIsSelected(index);
      }
    }
  }

  /// true if it's been added, false if it's been removed
  bool togglePostSelection({
    required int postId,
    int? index,
    bool resolveDesync = true,
    bool throwOnDesync = false,
  }) {
    logger.fine("togglePostSelection: Before");
    logger.finer("\tindices: ${selectedIndices.toSet()}"
        "\tposts: ${selectedPostIds.toSet()}");
    if (getIsPostSelected(postId) && (index == null || getIsSelected(index))) {
      _selectedPostIds.remove(postId);
      _selectedIndices.remove(index ?? -1);
      logger.finer("After: "
          "\n\tindices: ${selectedIndices.toSet()}"
          "\n\tposts: ${selectedPostIds.toSet()}");
      notifyListeners();
      return false;
    } else if (!getIsPostSelected(postId) &&
        (index == null || !getIsSelected(index))) {
      if (index != null) {
        _selectedIndices.add(index);
      }
      _selectedPostIds.add(postId);
      logger.finer("After: "
          "\n\tindices: ${selectedIndices.toSet()}"
          "\n\tposts: ${selectedPostIds.toSet()}");
      notifyListeners();
      return true;
    } else {
      if (resolveDesync) {
        logger.warning("Selected indices and posts desynced, resolving");
        _selectedIndices.clear();
        _selectedPostIds.clear();
        notifyListeners();
        return false;
      }
      logger.severe("Selected indices and posts desynced");
      if (throwOnDesync) {
        throw StateError("Selected indices and posts desynced");
      } else {
        return getIsPostSelected(postId);
      }
    }
  }

  /// true if it's been added, false if it's been removed
  bool assignPostSelection({
    required bool select,
    required int postId,
    int? index,
    bool resolveDesync = true,
    bool throwOnDesync = false,
  }) {
    logger.fine("assignPostSelection: Before");
    logger.finer("\tindices: ${selectedIndices.toSet()}"
        "\tposts: ${selectedPostIds.toSet()}");
    if (getIsPostSelected(postId) && (index == null || getIsSelected(index))) {
      if (!select) {
        _selectedPostIds.remove(postId);
        _selectedIndices.remove(index ?? -1);
        logger.finer("After: "
            "\n\tindices: ${selectedIndices.toSet()}"
            "\n\tposts: ${selectedPostIds.toSet()}");
        notifyListeners();
        return false;
      } else {
        logger.finest("Already selected");
        return true;
      }
    } else if (!getIsPostSelected(postId) &&
        (index == null || !getIsSelected(index))) {
      if (select) {
        if (index != null) {
          _selectedIndices.add(index);
        }
        _selectedPostIds.add(postId);
        logger.finer("After: "
            "\n\tindices: ${selectedIndices.toSet()}"
            "\n\tposts: ${selectedPostIds.toSet()}");
        notifyListeners();
        return true;
      } else {
        logger.finest("Already unselected");
        return true;
      }
    } else {
      if (resolveDesync) {
        logger.warning("Selected indices and posts desynced, resolving");
        _selectedIndices.clear();
        _selectedPostIds.clear();
        notifyListeners();
        return false;
      }
      logger.severe("Selected indices and posts desynced");
      if (throwOnDesync) {
        throw StateError("Selected indices and posts desynced");
      } else {
        return getIsPostSelected(postId);
      }
    }
  }

  /// true if it's been added, false if it's been removed
  void assignPostSelections({
    required bool select,
    required List<int> postIds,
    List<int>? index,
    bool resolveDesync = true,
    bool throwOnDesync = false,
  }) {
    for (var i = 0; i < postIds.length; i++) {
      assignPostSelection(select: select, postId: postIds[i], index: index?[i]);
    }
  }

  void clearSelections({bool clearIndices = true, bool clearPostIds = true}) {
    logger.fine(
      "Before clearing: "
      "\n\t_selectedIndices: $_selectedIndices,"
      "\n\t_selectedPostIds: $_selectedPostIds",
    );
    if (clearIndices) _selectedIndices.clear();
    if (clearPostIds) _selectedPostIds.clear();
    if (clearIndices || clearPostIds) notifyListeners();
    logger.finer(
      "After clearing: "
      "\n\t_selectedIndices: $_selectedIndices,"
      "\n\t_selectedPostIds: $_selectedPostIds",
    );
  }

  ListNotifier<int> makeSelectedPostIdList({bool listen = true}) {
    var r = ListNotifier.from(_selectedPostIds);
    r.addListener(() {
      final rs = r.toSet();
      if (!setEquals(_selectedPostIds, rs)) {
        logger.info("Generated list of selectedPostIds changed");
        _selectedPostIds.addAll(rs.difference(_selectedPostIds));
        _selectedPostIds.removeAll(_selectedPostIds.difference(rs));
        if (listen) notifyListeners();
      }
    });
    return r;
  }

  ListNotifier<E6PostResponse> makeSelectedPostList(
    final Iterable<E6PostResponse> posts, {
    final bool listen = true,
  }) =>
      makeSelectedPostListWithMapper(
          (int id) => posts.firstWhere((p) => p.id == id),
          listen: listen);

  ListNotifier<E6PostResponse> makeSelectedPostListFromMap(
    Map<int, E6PostResponse> posts, {
    bool listen = true,
  }) =>
      makeSelectedPostListWithMapper((int id) => posts[id]!, listen: listen);

  ListNotifier<E6PostResponse> makeSelectedPostListWithMapper(
    E6PostResponse Function(int id) mapToPosts, {
    bool listen = true,
  }) {
    var r = ListNotifier.from(_selectedPostIds.map(mapToPosts));
    void Function()? onSelectedChanged;
    void onListChanged() {
      final rs = r.map((e) => e.id).toSet();
      if (!setEquals(_selectedPostIds, rs)) {
        logger.info("Generated list of selectedPosts changed");
        _selectedPostIds
          ..removeListener(onSelectedChanged!)
          ..addAll(rs.difference(_selectedPostIds))
          ..removeAll(_selectedPostIds.difference(rs))
          ..addListener(onSelectedChanged);
        if (listen) notifyListeners();
      }
    }

    onSelectedChanged = () {
      final rs = r.toSet();
      final sps = _selectedPostIds.map(mapToPosts).toSet();
      if (!setEquals(_selectedPostIds, rs)) {
        logger.info("selectedPosts changed, changing generated list");
        r
          ..removeListener(onListChanged)
          ..addAll(sps.difference(rs));
        for (var e in rs.difference(sps)) {
          r.remove(e);
        }
        r.addListener(onListChanged);
        if (listen) notifyListeners();
      }
    };
    r.addListener(onListChanged);
    _selectedPostIds.addListener(onSelectedChanged);
    return r;
  }
}
