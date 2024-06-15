import 'package:flutter/foundation.dart';
import 'package:fuzzy/web/site.dart';

class SearchViewModel extends ChangeNotifier {
  bool _lazyLoad = false;
  bool get lazyLoad => _lazyLoad;
  bool toggleLazyLoad() {
    _lazyLoad = !_lazyLoad;
    notifyListeners();
    return _lazyLoad;
  }

  bool _lazyBuilding = false;
  bool get lazyBuilding => _lazyBuilding;
  bool toggleLazyBuilding() {
    _lazyBuilding = !_lazyBuilding;
    notifyListeners();
    return _lazyBuilding;
  }

  bool _forceSafe = false;
  bool get forceSafe => _forceSafe;
  bool toggleForceSafe() {
    _forceSafe = !_forceSafe;
    notifyListeners();
    return _forceSafe;
  }

  bool _sendAuthHeaders = false;
  bool get sendAuthHeaders => _sendAuthHeaders;
  bool toggleSendAuthHeaders() {
    _sendAuthHeaders = !_sendAuthHeaders;
    notifyListeners();
    if (_sendAuthHeaders && !E621AccessData.devData.isAssigned) {
      E621AccessData.devData
              .getItem();/* .then(
            (v) => util.snackbarMessageQueue.add(const SnackBar(
              content: Text("Dev e621 Auth Loaded"),
            )),
          ) */
    }
    return _sendAuthHeaders;
  }
}
