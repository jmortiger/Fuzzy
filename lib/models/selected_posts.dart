import 'package:flutter/foundation.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart' show E6PostResponse;
import 'package:j_util/j_util_full.dart';

import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/log_management.dart' show SymbolName;

class SelectedPosts with ChangeNotifier {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger((#SelectedPosts).name).logger;
  SelectedPosts({
    Set<int>? selectedPostIds,
  }) : _selectedPostIds = selectedPostIds == null
            ? SetNotifier<int>()
            : selectedPostIds is SetNotifier<int>
                ? selectedPostIds
                : SetNotifier<int>.from(selectedPostIds) {
    _selectedPostIds.addListener(notifyListeners);
  }

  final SetNotifier<int> _selectedPostIds /*  = <int>{} */;
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

  bool get areAnySelected => _selectedPostIds.isNotEmpty;
  bool getIsPostSelected(int id) => _selectedPostIds.contains(id);

  /// true if it's been added, false if it's been removed
  bool togglePostSelection({required int postId}) {
    logger.finer(
        "togglePostSelection: Before\n\tposts: ${selectedPostIds.toSet()}");
    if (getIsPostSelected(postId)) {
      _selectedPostIds.remove(postId);
      logger.finer("After: "
          "\n\tposts: ${selectedPostIds.toSet()}");
      notifyListeners();
      return false;
    } else {
      _selectedPostIds.add(postId);
      logger.finer("After: "
          "\n\tposts: ${selectedPostIds.toSet()}");
      notifyListeners();
      return true;
    }
  }

  /// true if it's been added, false if it's been removed
  bool assignPostSelection({
    required bool select,
    required int postId,
  }) {
    logger.fine(
        "assignPostSelection: Before\n\tposts: ${selectedPostIds.toSet()}");
    if (getIsPostSelected(postId)) {
      if (!select) {
        _selectedPostIds.remove(postId);
        logger.finer("After: "
            "\n\tposts: ${selectedPostIds.toSet()}");
        notifyListeners();
        return false;
      } else {
        logger.finest("Already selected");
        return true;
      }
    } else {
      if (select) {
        _selectedPostIds.add(postId);
        logger.finer("After: "
            "\n\tposts: ${selectedPostIds.toSet()}");
        notifyListeners();
        return true;
      } else {
        logger.finest("Already unselected");
        return true;
      }
    }
  }

  /// true if it's been added, false if it's been removed
  void assignPostSelections({
    required bool select,
    required List<int> postIds,
  }) {
    for (var i = 0; i < postIds.length; i++) {
      assignPostSelection(select: select, postId: postIds[i]);
    }
  }

  void clearSelections({bool clearIndices = true, bool clearPostIds = true}) {
    logger.fine(
      "Before clearing: "
      "\n\t_selectedPostIds: $_selectedPostIds",
    );
    if (clearPostIds) {
      _selectedPostIds.clear();
      notifyListeners();
    }
    logger.finer(
      "After clearing: "
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
    void Function()? onListChanged;
    void onSelectedChangedOuter() => onSelectedChanged?.call();
    void onListChangedOuter() => onListChanged?.call();
    onListChanged = () {
      final rs = r.map((e) => e.id).toSet();
      if (!setEquals(_selectedPostIds, rs)) {
        logger.info("Generated list of selectedPosts changed");
        _selectedPostIds.removeListener(onSelectedChangedOuter);
        _selectedPostIds
          ..addAll(rs.difference(_selectedPostIds))
          ..removeAll(_selectedPostIds.difference(rs))
          ..addListener(onSelectedChangedOuter);
        if (listen) notifyListeners();
      }
    };

    onSelectedChanged = () {
      final rs = r.toSet();
      final sps = _selectedPostIds.map(mapToPosts).toSet();
      if (!setEquals(_selectedPostIds, rs)) {
        logger.info("selectedPosts changed, changing generated list");
        r.removeListener(onListChangedOuter);
        r.addAll(sps.difference(rs));
        for (var e in rs.difference(sps)) {
          r.remove(e);
        }
        r.addListener(onListChangedOuter);
        if (listen) notifyListeners();
      }
    };
    r
      ..addListener(onListChangedOuter)
      ..addDisposeListener((_, __) => r.removeListener(onListChangedOuter))
      ..addDisposeListener(
          (_, __) => _selectedPostIds.removeListener(onSelectedChangedOuter));
    _selectedPostIds.addListener(onSelectedChangedOuter);
    return r;
  }
}
