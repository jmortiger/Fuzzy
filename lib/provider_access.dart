/* import 'package:flutter/material.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import 'models/search_cache.dart';

mixin ProviderAccessState<T extends StatefulWidget> on State<T> {
  final _sc = LateInstance<SearchCacheLegacy>();
  final _scl = LateInstance<SearchCacheLegacy>();
  final _sr = LateInstance<SearchResultsNotifier>();
  final _srl = LateInstance<SearchResultsNotifier>();
  SearchCacheLegacy get sc => _sc.isAssigned
      ? _sc.$
      : _sc.$ = Provider.of<SearchCacheLegacy>(context, listen: false);
  SearchCacheLegacy get scl => _scl.isAssigned
      ? _scl.$
      : _scl.$ = Provider.of<SearchCacheLegacy>(context, listen: false);
  SearchResultsNotifier get sr => _sr.isAssigned
      ? _sr.$
      : _sr.$ = Provider.of<SearchResultsNotifier>(context, listen: false);
  SearchResultsNotifier get srl => _srl.isAssigned
      ? _srl.$
      : _srl.$ = Provider.of<SearchResultsNotifier>(context, listen: true);
  @override
  void initState() {
    super.initState();
    _reassign();
  }

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reassign();
  }

  void _reassign() {
    _sc.$ = Provider.of<SearchCacheLegacy>(context, listen: false);
    _scl.$ = Provider.of<SearchCacheLegacy>(context, listen: true);
    _sr.$ = Provider.of<SearchResultsNotifier>(context, listen: false);
    _srl.$ = Provider.of<SearchResultsNotifier>(context, listen: true);
  }
}
 */
