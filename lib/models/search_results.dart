import 'package:flutter/material.dart';
import 'package:j_util/j_util_full.dart';

import 'package:fuzzy/log_management.dart' as lm;

class SearchResultsNotifier with ChangeNotifier {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("SearchResultsNotifier");
  // #endregion Logger
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
    print("selectedIndices assignment");
    if (_selectedIndices != value) {
      print("necessary");
      _selectedIndices =
          value is SetNotifier<int> ? value : SetNotifier<int>.from(value);
      notifyListeners();
    } else {
      print("unnecessary");
    }
  }

  SetNotifier<int> _selectedPostIds /*  = <int>{} */;
  Set<int> get selectedPostIds => _selectedPostIds;
  set selectedPostIds(Set<int> value) {
    if (_selectedPostIds != value) {
      _selectedPostIds =
          value is SetNotifier<int> ? value : SetNotifier<int>.from(value);
      notifyListeners();
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
}
