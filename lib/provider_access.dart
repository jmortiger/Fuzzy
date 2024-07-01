import 'package:flutter/material.dart';
import 'package:fuzzy/models/search_results.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

mixin ProviderAccessState<T extends StatefulWidget> on State<T> {
  final _sc = LateInstance<SearchCache>();
  final _scl = LateInstance<SearchCache>();
  final _sr = LateInstance<SearchResultsNotifier>();
  final _srl = LateInstance<SearchResultsNotifier>();
  SearchCache get sc => _sc.isAssigned
      ? _sc.$
      : _sc.$ = Provider.of<SearchCache>(context, listen: false);
  SearchCache get scl => _scl.isAssigned
      ? _scl.$
      : _scl.$ = Provider.of<SearchCache>(context, listen: false);
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
    _sc.$ = Provider.of<SearchCache>(context, listen: false);
    _scl.$ = Provider.of<SearchCache>(context, listen: true);
    _sr.$ = Provider.of<SearchResultsNotifier>(context, listen: false);
    _srl.$ = Provider.of<SearchResultsNotifier>(context, listen: true);
  }
}
