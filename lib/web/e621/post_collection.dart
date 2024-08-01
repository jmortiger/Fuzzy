import 'dart:async';
import 'dart:collection';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_cache.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/j_util_full.dart';
import 'package:fuzzy/log_management.dart' as lm;

class PostCollectionEvent extends JEventArgs {
  final List<FutureOr<E6PostResponse>> posts;

  PostCollectionEvent({required this.posts});
}

class PostCollection with ListMixin<E6PostEntry> {
  final LinkedList<E6PostEntry> _posts = LinkedList();
  LinkedList<E6PostEntry> get posts => _posts;
  @Event(name: "addPosts")
  final addPosts = JOwnedEvent<PostCollection, PostCollectionEvent>();
  // #region Collection Overrides
  @override
  set length(int l) {
    if (l == _posts.length) {
      return;
    } else if (l >= _posts.length) {
      throw ArgumentError.value(
        l,
        "l",
        "New length ($l) greater than old length (${_posts.length}). "
            "Can't extend list",
      );
    }
  }

  @override
  operator [](int index) => _posts.elementAt(index);

  @override
  void operator []=(int index, value) {
    _posts.elementAt(index).$ = value.$;
  }

  @override
  int get length => _posts.length;
  // #endregion Collection Overrides
}

class SelfManagedPostCollectionBad extends SearchCache
    implements E6PostEntries {
  PostCollection? _postsStash;
  PostCollection? get postsStash => _postsStash;
  set postsStash(PostCollection? value) {
    _postsStash = value;
    notifyListeners();
  }

  SelfManagedPostCollectionBad({
    PostCollection? postsStash,
  }) : _postsStash = postsStash;

  // @override
  // set posts(Iterable<E6PostEntry>? v) {
  //   postsStash?._posts.clear();
  //   postsStash?._posts.addAll(v!);
  // }

  @override
  Iterable<E6PostEntry> get posts => postsStash!._posts;
  @override
  int get count => postsStash!.length % SearchView.i.postsPerPage;

  @override
  final Set<int> restrictedIndices = {};

  @override
  E6PostEntry? tryGet(int index, {bool checkForValidFileUrl = true}) {
    // TODO: implement tryGet
    throw UnimplementedError();
  }

  @override
  E6PostEntry operator [](int index) {
    // TODO: implement 
    // if (_postsStash!.length <= index && !_postCapacity.isAssigned) {
    //   bool mn = false;
    //   for (var i = _postsStash!.length;
    //       i <= index && (mn = _postsStashIterator.moveNext());
    //       i++) {
    //     _postsStash!.add(_postsStashIterator.current);
    //   }
    //   if (mn == false && !isFullyProcessed) {
    //     _postCapacity.$ = _postsStash!.length;
    //     onFullyIterated.invoke(FullyIteratedArgs(_postsStash!));
    //   }
    // }
    return _postsStash![index];
  }

  @override
  void advanceToEnd() {
    tryGet(postsStash!.length +
        (SearchView.i.postsPerPage -
            (postsStash!.length % SearchView.i.postsPerPage)));
  }
}

final class E6PostEntry extends LinkedListEntry<E6PostEntry>
    with ValueAsyncMixin<E6PostResponse> {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostEntry");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  // final ValueAsync<E6PostResponse> _inst;
  // @override
  // bool get isValue => _inst.isValue;
  // @override
  // bool get isFuture => _inst.isFuture;
  // @override
  // bool get isComplete => _inst.isComplete;
  // @override
  // Future<E6PostResponse>? get futureSafe => _inst.futureSafe;
  // @override
  // Future<E6PostResponse> get future => _inst.future;
  // @override
  // E6PostResponse? get $Safe => _inst.$Safe;
  // @override
  // E6PostResponse get $ => _inst.$;
  // @override
  // set $(E6PostResponse v) => _inst.$;

  // @override
  // clearErrorData() => _inst.clearErrorData();

  // @override
  // ({Object error, StackTrace? stackTrace})? get errorData => _inst.errorData;

  // @override
  // Function makeDefaultCatchError([bool trySilenceErrors = false]) =>
  //     _inst.makeDefaultCatchError(trySilenceErrors);

  // @override
  // FutureOr<E6PostResponse> get value => _inst.value;

  @override
  final ValueAsync<E6PostResponse> inst;

  E6PostEntry({required FutureOr<E6PostResponse> value})
      : inst = ValueAsync.catchError(
            value: value,
            cacheErrors: false,
            catchError: (e, s) {
              logger.severe("Failed to resolve post", e, s);
              return E6PostResponse.error;
            });
}

/* final class E6PostEntry extends LinkedListEntry<E6PostEntry> {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostEntry");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  final FutureOr<E6PostResponse> value;
  final _value = LateInstance<E6PostResponse>();
  // late dynamic _error;
  // late StackTrace _stackTrace;
  bool get isValue => value is E6PostResponse;
  bool get isFuture => value is Future<E6PostResponse>;
  bool get isComplete => _value.isAssigned;
  Future<E6PostResponse>? get futureSafe => value as Future<E6PostResponse>?;
  Future<E6PostResponse> get future => value as Future<E6PostResponse>;
  E6PostResponse? get $Safe => _value.$Safe;
  E6PostResponse get $ => _value.$;
  set $(E6PostResponse v) => _value.$ = v;

  E6PostEntry({required this.value}) {
    if (isFuture) {
      future.catchError((e, s) {
        // _error = e;
        // _stackTrace = s;
        logger.severe("Failed to resolve post", e, s);
        return E6PostResponse.error;
      }).then((v) => _value.$ = v);
    } else if (isValue) {
      _value.$ = value as E6PostResponse;
    }
  }
} 
class E6PostOrFuture {
  // #region Logger
  static late final lRecord = lm.genLogger("E6PostOrFuture");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  final FutureOr<E6PostResponse> value;
  final _value = LateInstance<E6PostResponse>();
  // late dynamic _error;
  // late StackTrace _stackTrace;
  bool get isValue => value is E6PostResponse;
  bool get isFuture => value is Future<E6PostResponse>;
  bool get isComplete => _value.isAssigned;
  Future<E6PostResponse>? get futureSafe => value as Future<E6PostResponse>?;
  Future<E6PostResponse> get future => value as Future<E6PostResponse>;
  E6PostResponse? get $Safe => _value.$Safe;
  E6PostResponse get $ => _value.$;
  set $(E6PostResponse v) => _value.$ = v;

  E6PostOrFuture({required this.value}) {
    if (isFuture) {
      future.catchError((e, s) {
        // _error = e;
        // _stackTrace = s;
        logger.severe("Failed to resolve post", e, s);
        return E6PostResponse.error;
      }).then((v) => _value.$ = v);
    } else if (isValue) {
      _value.$ = value as E6PostResponse;
    }
  }
} */
