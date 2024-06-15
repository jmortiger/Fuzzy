// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fuzzy/app_settings.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/search_view_model.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:http/http.dart' as http;
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import '../widgets/w_search_result_page_navigation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    onSelectionCleared.subscribe(() {
      setState(() => selectedIndices.clear());
    });
    if (!E621AccessData.devData.isAssigned) {
      E621AccessData.devData.getItem();
    }
    super.initState();
  }

  // void workThroughSnackbarQueue() {
  //   if (util.snackbarMessageQueue.isNotEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       util.snackbarMessageQueue.removeLast(),
  //     );
  //   }
  //   if (util.snackbarBuilderMessageQueue.isNotEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       util.snackbarBuilderMessageQueue.removeLast()(context),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // workThroughSnackbarQueue();
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(context),//const Text("Fuzzy"),
      ),
      body: SafeArea(child: buildSearchView(context)),
      endDrawer: _buildDrawer(context),
      floatingActionButton: _buildFab(context),
    );
  }

  ExpandableFab? _buildFab(BuildContext context) {
    return selectedIndices.isNotEmpty
        ? ExpandableFab(
            distance: 112,
            children: [
              ActionButton(
                icon: const Icon(Icons.clear),
                tooltip: "Clear Selections",
                onPressed: () => onSelectionCleared.invoke(),
              ),
              ActionButton(
                icon: const Icon(Icons.add),
                tooltip: "Add selected to pool",
                onPressed: () {
                  print("To Be Implemented");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("To Be Implemented")),
                  );
                },
              ),
              ActionButton(
                icon: const Icon(Icons.favorite),
                tooltip: "Add selected to favorites",
                onPressed: () async {
                  print(
                      "Adding ${selectedIndices.length} posts to favorites...");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            "Adding ${selectedIndices.length} posts to favorites...")),
                  );
                  _sendRequestBatch(
                    () =>
                        selectedIndices.map((e) => E621.initAddFavoriteRequest(
                              posts!.tryGet(e)!.id,
                              username: E621AccessData.devUsername,
                              apiKey: E621AccessData.devApiKey,
                            )),
                    onComplete: (responses) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts added to favorites!"),
                        action: SnackBarAction(
                          label: "Undo",
                          onPressed: () async {
                            _sendRequestBatch(
                              () => responses.map(
                                (e) => E621.initDeleteFavoriteRequest(
                                  int.parse(
                                    e.request!.url.queryParameters["post_id"]!,
                                  ),
                                  username: E621AccessData.devUsername,
                                  apiKey: E621AccessData.devApiKey,
                                ),
                              ),
                              onComplete: (responses) =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              ActionButton(
                icon: const Icon(Icons.delete),
                tooltip: "Remove selected from pool",
                onPressed: () {
                  print("To Be Implemented");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("To Be Implemented")),
                  );
                },
              ),
              ActionButton(
                icon: const Icon(Icons.heart_broken_outlined),
                tooltip: "Remove selected from favorites",
                onPressed: () async {
                  print("Removing ${selectedIndices.length}"
                      " posts from favorites...");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Removing ${selectedIndices.length}"
                          " posts from favorites..."),
                    ),
                  );
                  var postIds = <int>[];
                  _sendRequestBatch(
                    () => selectedIndices.map(
                      (e) {
                        var id = posts!.tryGet(e)!.id;
                        postIds.add(id);
                        return E621.initDeleteFavoriteRequest(
                          id,
                          username: E621AccessData.devUsername,
                          apiKey: E621AccessData.devApiKey,
                        );
                      },
                    ),
                    onError: (error, trace) {
                      print(error);
                    },
                    onComplete: (responses) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
                        action: SnackBarAction(
                          label: "Undo",
                          onPressed: () async {
                            _sendRequestBatch(
                              () => responses.map(
                                (e) => E621.initAddFavoriteRequest(
                                  int.parse(
                                    e.request!.url.queryParameters["post_id"]!,
                                  ),
                                  username: E621AccessData.devUsername,
                                  apiKey: E621AccessData.devApiKey,
                                ),
                              ),
                              onComplete: (responses) =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          )
        : null;
  }

  Future<void> _sendRequestBatch(
    Iterable<http.Request> Function() requestGenerator, {
    FutureOr<void> Function(List<http.StreamedResponse> responses)? onComplete,
    void Function(Object? error, StackTrace trace)? onError =
        util.defaultOnError,
  }) async {
    var responses = <http.StreamedResponse>[],
        stream = E621
            .sendRequests(requestGenerator())
            .asyncMap((event) => event)
            .asyncMap((event) async {
          await event.stream.length;
          return event;
        }).handleError(onError as Function);
    await for (final srf in stream) {
      responses.add(srf);
    }
    onComplete?.call(responses);
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text("Menu"),
          ),
          ListTile(
            title: const Text("Go to settings"),
            onTap: () {
              // Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ));
            },
          ),
          ListTile(
            title: const Text("Toggle Lazy Loading"),
            leading: lazyLoad
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print("Before: $lazyLoad");
              setState(() => toggleLazyLoad());
              print("After: $lazyLoad");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Lazy Building"),
            leading: lazyBuilding
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print("Before: $lazyBuilding");
              setState(() => toggleLazyBuilding());
              print("After: $lazyBuilding");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Auth headers"),
            leading: sendAuthHeaders
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print("Before: $sendAuthHeaders");
              setState(
                () => svm.toggleSendAuthHeaders(),
              );
              print("After: $sendAuthHeaders");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Force Safe"),
            leading: forceSafe
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print("Before: $forceSafe");
              setState(() => toggleForceSafe());
              print("After: $forceSafe");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Image Display Method"),
            // leading: lazyLoad ? const Icon(Icons.check_box) :const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print("Before: ${imageFit.name}");
              imageFit =
                  imageFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
              print("After: ${imageFit.name}");
              // Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // #region From WSearchView
  SearchViewModel get svm =>
      Provider.of<SearchViewModel>(context, listen: false);
  bool get lazyLoad => svm.lazyLoad;
  bool toggleLazyLoad() => svm.toggleLazyLoad();
  bool get lazyBuilding => svm.lazyBuilding;
  bool toggleLazyBuilding() => svm.toggleLazyBuilding();
  bool get forceSafe => svm.forceSafe;
  bool toggleForceSafe() => svm.toggleForceSafe();
  bool get sendAuthHeaders => svm.sendAuthHeaders;
  bool toggleSendAuthHeaders() => svm.toggleSendAuthHeaders();

  E6Posts? posts;
  Set<int> selectedIndices = {};
  JPureEvent onSelectionCleared = JPureEvent();
  String priorSearchText = "";
  int? _firstPostIdCached;
  int? get firstPostOnPageId => posts?.tryGet(0)?.id;
  int? _lastPostIdCached;
  int? _lastPostOnPageIdCached;
  bool? _hasNextPageCached;
  bool? get hasPriorPage =>
      _firstPostIdCached != null &&
      _firstPostIdCached! > (firstPostOnPageId ?? _firstPostIdCached!);

  // #region Only Needed in search view
  String searchText = "";
  Future<http.StreamedResponse>? pr;
  int? currentPostCollectionExpectedSize;
  // bool buildNavigator = false;
  // #endregion Only Needed in search view

  @widgetFactory
  Padding _buildSearchBar(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        // child: simpleTextField(),
        child: autoCompleteTextField(),
      );
  }

  @widgetFactory
  Widget buildSearchView(BuildContext context) {
    return Column(
      children: [
        // _buildSearchBar(context),
        if (posts == null && pr != null)
          Expanded(
            child: Center(
                child: pr != null
                    ? const AspectRatio(
                        aspectRatio: 1,
                        child: CircularProgressIndicator(),
                      )
                    : const Placeholder()),
          ),
        if (posts != null)
          (() {
            if (pr != null) {
              print("Results Came back: $priorSearchText");
              // priorSearchText = searchText;
              pr = null;
            }
            return Expanded(
              child: WPostSearchResults(
                key: ObjectKey(posts!),
                posts: posts!,
                expectedCount: lazyLoad
                    ? (currentPostCollectionExpectedSize ?? 50)
                    : posts!.count,
                searchText: searchText,
                onPostsSelected: (indices, newest) {
                  setState(() {
                    selectedIndices = indices;
                  });
                },
                onSelectionCleared: onSelectionCleared,
                useLazyBuilding: lazyBuilding,
              ),
            );
          })(),
        if (posts != null &&
            (posts.runtimeType == E6PostsSync ||
                (posts as E6PostsLazy).isFullyProcessed))
          // Builder(builder: (context) {
          (() {
            print("BUILDING PAGE NAVIGATION");
            // getHasNextPage(
            //   tags: priorSearchText,
            //   // lastPostId: _lastPostOnPageIdCached,
            //   lastPostId: posts?.tryGet(posts!.count - 1)?.id,
            // );
            return WSearchResultPageNavigation(
              onNextPage: _hasNextPageCached ?? false
                  ? () => _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'b',
                        postId: _lastPostOnPageIdCached,
                        tags: priorSearchText,
                      )
                  : null,
              onPriorPage: hasPriorPage ?? false
                  ? () => _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'a',
                        postId: firstPostOnPageId,
                        tags: priorSearchText,
                      )
                  : null,
            );
          })(),
      ],
    );
  }

  // TODO: Just launch tag search requests for autocomplete, wrap in a class
  @widgetFactory
  Autocomplete<String> autoCompleteTextField() {
    return Autocomplete<String>(
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        void Function() onFieldSubmitted,
      ) =>
          TextField(
        controller: textEditingController,
        focusNode: focusNode,
        onSubmitted: (s) => setState(() {
          // onFieldSubmitted();
          searchText = textEditingController.text;
          if (searchText.isNotEmpty) {
            _sendSearchAndUpdateState(tags: searchText);
          } else {
            _sendSearchAndUpdateState();
          }
        }),
      ),
      optionsBuilder: (TextEditingValue textEditingValue) {
        var db = !util.DO_NOT_USE_TAG_DB ? util.tagDbLazy.itemSafe : null;
        if (db == null || textEditingValue.text.isEmpty) {
          if (AppSettings.i.favoriteTags.isEmpty) {
            return const Iterable<String>.empty();
          } else {
            return [
              textEditingValue.text,
              ...AppSettings.i.favoriteTags.where(
                (element) => !textEditingValue.text.contains(element),
              )
            ];
          }
        }
        var (s, e) = db.getCharStartAndEnd(textEditingValue.text[0]);
        print("range For ${textEditingValue.text[0]}: $s - $e");
        if (textEditingValue.text.length == 1) {
          return [
            textEditingValue.text,
            ...(db.tagsByString.queue.getRange(s, e).toList(growable: false)
                  ..sort((a, b) => b.postCount - a.postCount))
                .map((e) => e.name),
          ];
        }
        var t = db.tagsByString.queue.getRange(s, e).toList(growable: false),
            s1 = t.indexWhere(
                (element) => element.name.startsWith(textEditingValue.text));
        if (s1 == -1) {
          s1 = t.indexWhere((element) => element.name.startsWith(
                textEditingValue.text.substring(
                  0,
                  textEditingValue.text.length - 1,
                ),
              ));
        }
        if (s1 == -1) return const Iterable<String>.empty();
        var e1 = t.lastIndexWhere(
            (element) => element.name.startsWith(textEditingValue.text));
        if (e1 == -1) {
          e1 = t.lastIndexWhere((element) =>
              element.name.startsWith(textEditingValue.text.substring(
                0,
                textEditingValue.text.length - 1,
              )));
        }
        if (e1 == -1) return const Iterable<String>.empty();
        return [
          textEditingValue.text,
          ...(t.getRange(s1, e1).toList(growable: false)
                ..sort((a, b) => b.postCount - a.postCount))
              .map((e) => e.name),
        ];
      },
      displayStringForOption: (option) => option,
      onSelected: (option) => setState(() {
        searchText += option;
      }),
    );
  }

  @widgetFactory
  TextField simpleTextField() {
    return TextField(
      autofillHints: const [AutofillHints.url],
      autocorrect: true,
      autofocus: true,
      enableSuggestions: true,
      onSubmitted: (value) => setState(() {
        searchText = value;
        _sendSearchAndUpdateState(tags: value);
      }),
    );
  }

  Future<bool> getHasNextPage({
    String? tags,
    // int limit = 50,
    int? lastPostId,
  }) async {
    if (posts == null) throw StateError("No current posts");
    if (lastPostId == null) {
      if (posts.runtimeType == E6PostsLazy) {
        posts?.tryGet(E621.maxPostsPerSearch + 5);
      }
      lastPostId ??= posts!.tryGet(posts!.count - 1)?.id;
    }
    if (lastPostId == null) {
      throw StateError("Couldn't determine current page's last post's id.");
    }
    if (_lastPostOnPageIdCached == lastPostId && _hasNextPageCached != null) {
      return _hasNextPageCached!;
    }
    try {
      setState(() {
        _lastPostOnPageIdCached = lastPostId;
      });
    } /* on Exception  */ catch (e) {
      print(e);
      // print(e);
      _lastPostOnPageIdCached = lastPostId;
    }
    var (:username, :apiKey) = devGetAuth();
    if (tags == "fav:***REMOVED***) {
      print("Here");
    }
    var out = E6PostsSync.fromJson(
      jsonDecode(
        (await (await E621.sendRequest(
          E621.initSearchForLastPostRequest(
            tags: priorSearchText,
            apiKey: apiKey,
            username: username,
          ),
        ))
            .stream
            .bytesToString()),
      ) as JsonOut,
    );
    if (out.posts.isEmpty) {
      try {
        setState(() {
          _hasNextPageCached = false;
        });
      } /* on Exception */ catch (e) {
        print(e);
        _hasNextPageCached = false;
      }
      return _hasNextPageCached = false;
    }
    if (out.posts.length != 1) {
      // TODO: Warn, shouldn't be possible.
    }
    try {
      setState(() {
        _lastPostIdCached = out.posts.last.id;
        _hasNextPageCached = (lastPostId != _lastPostIdCached);
      });
    } catch (e) {
      _lastPostIdCached = out.posts.last.id;
      return _hasNextPageCached = (lastPostId != out.posts.last.id);
    }
    return (lastPostId != out.posts.last.id);
  }

  ({String? username, String? apiKey}) devGetAuth() =>
      sendAuthHeaders && E621AccessData.devData.isAssigned
          ? (
              username: E621AccessData.devData.item.username,
              apiKey: E621AccessData.devData.item.apiKey,
            )
          : (username: null, apiKey: null);

  http.Request initSearchRequest({
    String tags = "jun_kobayashi",
    int limit = 50,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    currentPostCollectionExpectedSize = limit;
    var (:apiKey, :username) = devGetAuth();
    return E621.initSearchRequest(
      tags: tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      apiKey: apiKey,
      username: username,
    );
  }

  /// Call inside of setState
  void _sendSearchAndUpdateState({
    String tags = "jun_kobayashi",
    int limit = 50,
    String? pageModifier,
    int? postId,
    int? pageNumber,
  }) {
    bool isNewRequest = false;
    if (isNewRequest = (priorSearchText != tags)) {
      print("Request For New Terms: $priorSearchText -> $tags ("
          "pageModifier = $pageModifier, "
          "postId = $postId, "
          "pageNumber = $pageNumber)");
      _lastPostIdCached = null;
      _firstPostIdCached = null;
      priorSearchText = tags;
    } else {
      print("Request For Same Terms: $priorSearchText ("
          "pageModifier = $pageModifier, "
          "postId = $postId, "
          "pageNumber = $pageNumber)");
    }
    _hasNextPageCached = null;
    _lastPostOnPageIdCached = null;
    pr = initSearchRequest(
      tags: forceSafe ? "$tags rating:safe" : tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
    ).send();
    pr!.then((value) {
      value.stream.bytesToString().then((v) {
        setState(() {
          pr = null;
          posts = lazyLoad
              ? E6PostsLazy.fromJson(json.decode(v) as Map<String, dynamic>)
              : E6PostsSync.fromJson(json.decode(v) as Map<String, dynamic>);
          if (posts.runtimeType == E6PostsLazy) {
            (posts as E6PostsLazy).onFullyIterated.subscribe((a) =>
                    getHasNextPage(
                        tags: priorSearchText, lastPostId: a.posts.last.id)
                /* .then((v) => setState(() {
                          buildNavigator = v;
                        })) */
                );
          } else {
            getHasNextPage(
                    tags: priorSearchText,
                    lastPostId: (posts as E6PostsSync).posts.last.id)
                /* .then((v) => setState(() {
                      buildNavigator = v;
                    })) */
                ;
          }
          if (isNewRequest) _firstPostIdCached = posts?.tryGet(0)?.id;
        });
      });
    });
  }
  // #endregion From WSearchView
}
