import 'package:flutter/material.dart';
import 'package:j_util/j_util_full.dart';

import 'package:fuzzy/log_management.dart' as lm;

final print = lm.genPrint("main");

class SearchResultsNotifier with ChangeNotifier {
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
  SetNotifier<int> _selectedIndices /*  = <int>{} */;
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
  }) {
    print("SRN.toggleSelection: ");
    // print("indices: $selectedIndices");
    // print("posts: $selectedPostIds");
    if (getIsSelected(index) && (postId == null || getIsPostSelected(postId))) {
      _selectedPostIds.remove(postId ?? -1);
      _selectedIndices.remove(index);
      // print("After: ");
      // print("indices: $selectedIndices");
      // print("posts: $selectedPostIds");
      // print("notifying listeners");
      notifyListeners();
      return false;
    } else if (!getIsSelected(index) &&
        (postId == null || !getIsPostSelected(postId))) {
      if (postId != null) {
        _selectedPostIds.add(postId);
      }
      _selectedIndices.add(index);
      // print("After: ");
      // print("indices: $selectedIndices");
      // print("posts: $selectedPostIds");
      // print("notifying listeners");
      notifyListeners();
      return true;
    } else {
      if (resolveDesync) {
        _selectedIndices.clear();
        _selectedPostIds.clear();
      }
      throw StateError("Selected indices and posts desynced");
    }
  }
}

class SearchResults with ChangeNotifier {
  var _selectedIndices = <int>{};
  Set<int> get selectedIndices => _selectedIndices;
  set selectedIndices(Set<int> value) {
    _selectedIndices = value;
    notifyListeners();
  }

  var _selectedPostIds = <int>{};
  Set<int> get selectedPostIds => _selectedPostIds;
  set selectedPostIds(Set<int> value) {
    _selectedPostIds = value;
    notifyListeners();
  }

  bool get areAnySelected => _selectedIndices.isNotEmpty;
  bool getIsSelected(int index) => _selectedIndices.contains(index);
  bool getIsPostSelected(int id) => _selectedPostIds.contains(id);

  /// true if it's been added, false if it's been removed
  bool toggleSelection({required int index, int? postId}) {
    if (getIsSelected(index) && (postId == null || getIsPostSelected(postId))) {
      _selectedPostIds.remove(postId ?? -1);
      _selectedIndices.remove(index);
      notifyListeners();
      return false;
    } else if (!getIsSelected(index) &&
        (postId == null || !getIsPostSelected(postId))) {
      if (postId != null) {
        _selectedPostIds.add(postId);
      }
      _selectedIndices.add(index);
      notifyListeners();
      return true;
    } else {
      throw StateError("Selected indices and posts desynced");
    }
  }
}
