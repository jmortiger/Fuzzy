import 'package:flutter/material.dart';

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
    } else if (!getIsSelected(index) && (postId == null || !getIsPostSelected(postId))) {
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
