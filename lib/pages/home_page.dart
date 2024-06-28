// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/saved_searches_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/widgets/w_search_result_page_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:j_util/j_util_full.dart';
import 'package:provider/provider.dart';

import '../widgets/w_home_end_drawer.dart';

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
    if (!E621AccessData.devAccessData.isAssigned) {
      E621AccessData.devAccessData.getItem();
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
        title: _buildSearchBar(context),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedSearchesPageProvider(),
                )).then(
              (value) => value == null
                  ? null
                  : setState(() {
                      searchText = value;
                      svm.fillTextBarWithSearchString = true;
                      (searchText.isNotEmpty)
                          ? _sendSearchAndUpdateState(tags: searchText)
                          : _sendSearchAndUpdateState();
                    }),
            );
          },
        ),
      ),
      body: SafeArea(child: buildSearchView(context)),
      endDrawer: WHomeEndDrawer(
        onSearchRequested: (searchText) {
          svm.searchText = searchText;
          svm.fillTextBarWithSearchString = true;
          setState(() {
            _sendSearchAndUpdateState(tags: searchText);
          });
        },
      ), //_buildDrawer(context),
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
                tooltip: "Add selected to set",
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
                  E621.sendAddFavoriteRequestBatch(
                    // () =>
                    selectedIndices.map((e) => //E621.initAddFavoriteRequest(
                        posts!.tryGet(e)!.id),
                    username: E621AccessData.devUsername,
                    apiKey: E621AccessData.devApiKey,
                    // )),
                    onComplete: (responses) {
                      var sbs =
                          "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts added to favorites!";
                      responses
                          .where((r) => r.statusCode == 422)
                          .forEach((r) async {
                        var //rBody = await http.ByteStream(r.stream.asBroadcastStream()).bytesToString(),
                            pId = int.parse(
                                r.request!.url.queryParameters["post_id"]!);
                        // E621.favFailed.invoke(
                        //   PostActionArgs(
                        //     post: posts![
                        //         selectedIndices.firstWhere((e) => posts![e].id == pId)],
                        //     responseBody: rBody,
                        //     statusCode: r.statusCodeInfo,
                        //   ),
                        // );
                        if (mounted &&
                            Provider.of<CachedFavorites>(this.context,
                                    listen: false)
                                .postIds
                                .contains(pId)) {
                          sbs += " $pId Cached";
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(sbs),
                          action: SnackBarAction(
                            label: "Undo",
                            onPressed: () async {
                              E621.sendDeleteFavoriteRequestBatch(
                                /* () =>  */ responses.map(
                                    (e) => //E621.initDeleteFavoriteRequest(
                                        int.parse(
                                          e.request!.url
                                              .queryParameters["post_id"]!,
                                        )),
                                username: E621AccessData.devUsername,
                                apiKey: E621AccessData.devApiKey,
                                // ),
                                // ),
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
                      );
                    },
                  );
                },
              ),
              ActionButton(
                icon: const Icon(Icons.delete),
                tooltip: "Remove selected from set",
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
                  E621.sendRequestBatch(
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
                            E621.sendRequestBatch(
                              () => responses.map(
                                (e) => E621.initAddFavoriteRequest(
                                  int.parse(
                                    e.request!.url.queryParameters["post_id"]!,
                                  ),
                                  username: E621AccessData.devUsername,
                                  apiKey: E621AccessData.devApiKey,
                                ),
                              ),
                              onComplete: (responses) {
                                responses
                                    .where((r) => r.statusCode == 422)
                                    .forEach((r) async {
                                  var rBody = await r.stream.bytesToString();
                                  E621.favFailed.invoke(
                                    PostActionArgs(
                                      post: posts![selectedIndices.firstWhere(
                                          (e) =>
                                              posts![e].id ==
                                              int.parse(r.request!.url
                                                      .queryParameters[
                                                  "post_id"]!))],
                                      responseBody: rBody,
                                      statusCode: r.statusCodeInfo,
                                    ),
                                  );
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "${responses.where((element) => element.statusCodeInfo.isSuccessful).length}/${responses.length} posts removed from favorites!"),
                                  ),
                                );
                              },
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

  // static Future<void> _sendRequestBatch(
  //   Iterable<http.Request> Function() requestGenerator, {
  //   FutureOr<void> Function(List<http.StreamedResponse> responses)? onComplete,
  //   void Function(Object? error, StackTrace trace)? onError =
  //       util.defaultOnError,
  // }) async {
  //   var responses = <http.StreamedResponse>[],
  //       stream = E621
  //           .sendRequests(requestGenerator())
  //           .asyncMap((event) => event)
  //           .asyncMap((event) async {
  //         await event.stream.length;
  //         return event;
  //       }).handleError(onError as Function);
  //   await for (final srf in stream) {
  //     responses.add(srf);
  //   }
  //   onComplete?.call(responses);
  // }

  // #region From WSearchView
  SearchViewModel get svm =>
      Provider.of<SearchViewModel>(context, listen: false);

  Set<int> selectedIndices = {};
  JPureEvent onSelectionCleared = JPureEvent();

  String get priorSearchText => svm.priorSearchText;
  set priorSearchText(String value) => svm.priorSearchText = value;
  // #region SearchCache
  SearchCache get sc => Provider.of<SearchCache>(context, listen: false);
  E6Posts? get posts => sc.posts;
  int? get firstPostOnPageId => sc.firstPostOnPageId;
  set posts(E6Posts? value) => sc.posts = value;
  int? get firstPostIdCached => sc.firstPostIdCached;
  set firstPostIdCached(int? value) => sc.firstPostIdCached = value;
  int? get lastPostIdCached => sc.lastPostIdCached;
  set lastPostIdCached(int? value) => sc.lastPostIdCached = value;
  int? get lastPostOnPageIdCached => sc.lastPostOnPageIdCached;
  set lastPostOnPageIdCached(int? value) => sc.lastPostOnPageIdCached = value;
  bool? get hasNextPageCached => sc.hasNextPageCached;
  set hasNextPageCached(bool? value) => sc.hasNextPageCached = value;
  bool? get hasPriorPage => sc.hasPriorPage;
  // #endregion SearchCache

  // #region Only Needed in search view
  String get searchText => svm.searchText;
  set searchText(String value) {
    svm.searchText = value;
  }

  Future<SearchResultArgs>? get pr => svm.pr;
  set pr(Future<SearchResultArgs>? value) => svm.pr = value;
  int? currentPostCollectionExpectedSize;
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
              // print("371: pr: $pr");
              // pr = null;
            }
            // if (posts!.posts.firstOrNull == null) {
            //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No Results. Did you mean to login?")));
            // }
            return Expanded(
              child: WPostSearchResults(
                key: ObjectKey(posts!),
                posts: posts!,
                expectedCount: svm.lazyLoad
                    ? (currentPostCollectionExpectedSize ?? 50)
                    : posts!.count,
                onPostsSelected: (indices, newest) {
                  setState(() {
                    selectedIndices = indices;
                  });
                },
                onSelectionCleared: onSelectionCleared,
                useLazyBuilding: svm.lazyBuilding,
              ),
            );
          })(),
        if (posts?.posts.firstOrNull == null)
          const Align(
            alignment: AlignmentDirectional.topCenter,
            child: Text("No Results"),
          ),
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
              onNextPage: hasNextPageCached ?? false
                  ? () => _sendSearchAndUpdateState(
                        limit: SearchView.i.postsPerPage,
                        pageModifier: 'b',
                        postId: lastPostOnPageIdCached,
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
      ) {
        if (svm.fillTextBarWithSearchString) {
          svm.fillTextBarWithSearchString = false;
          textEditingController.text = searchText;
        }
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          onSubmitted: (s) => setState(() {
            // onFieldSubmitted();
            searchText = textEditingController.text;
            (searchText.isNotEmpty)
                ? _sendSearchAndUpdateState(tags: searchText)
                : _sendSearchAndUpdateState();
          }),
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        var db = !util.DO_NOT_USE_TAG_DB ? util.tagDbLazy.itemSafe : null;
        if (db == null || textEditingValue.text.isEmpty) {
          if (AppSettings.i?.favoriteTags.isEmpty ?? true) {
            return const Iterable<String>.empty();
          } else {
            return [
              textEditingValue.text,
              ...AppSettings.i!.favoriteTags.where(
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
        // Advance to the end, fully load the list
        posts?.tryGet(E621.maxPostsPerSearch + 5);
      }
      lastPostId ??= posts!.tryGet(posts!.count - 1)?.id;
    }
    if (lastPostId == null) {
      throw StateError("Couldn't determine current page's last post's id.");
    }
    if (lastPostOnPageIdCached == lastPostId && hasNextPageCached != null) {
      return hasNextPageCached!;
    }
    try {
      setState(() {
        lastPostOnPageIdCached = lastPostId;
      });
    } catch (e) {
      print(e);
      lastPostOnPageIdCached = lastPostId;
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
          hasNextPageCached = false;
        });
      } /* on Exception */ catch (e) {
        print(e);
        hasNextPageCached = false;
      }
      return hasNextPageCached = false;
    }
    if (out.posts.length != 1) {
      // TODO: Warn, shouldn't be possible.
    }
    try {
      setState(() {
        lastPostIdCached = out.posts.last.id;
        hasNextPageCached = (lastPostId != lastPostIdCached);
      });
    } catch (e) {
      lastPostIdCached = out.posts.last.id;
      return hasNextPageCached = (lastPostId != out.posts.last.id);
    }
    return (lastPostId != out.posts.last.id);
  }

  ({String? username, String? apiKey}) devGetAuth() =>
      svm.sendAuthHeaders && E621AccessData.devAccessData.isAssigned
          ? (
              username: E621AccessData.devAccessData.item.username,
              apiKey: E621AccessData.devAccessData.item.apiKey,
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
    var out = "pageModifier = $pageModifier, "
          "postId = $postId, "
          "pageNumber = $pageNumber,"
          "projectedTrueTags = ${E621.fillTagTemplate(tags)})";
    if (isNewRequest = (priorSearchText != tags)) {
      out = "Request For New Terms: $priorSearchText -> $tags ($out";
      lastPostIdCached = null;
      firstPostIdCached = null;
      priorSearchText = tags;
    } else {
      out = "Request For Same Terms: $priorSearchText ($out";
    }
    print(out);
    hasNextPageCached = null;
    lastPostOnPageIdCached = null;
    var (:username, :apiKey) = devGetAuth();
    pr = E621.performPostSearch(
      tags: svm.forceSafe ? "$tags rating:safe" : tags,
      limit: limit,
      pageModifier: pageModifier,
      pageNumber: pageNumber,
      postId: postId,
      apiKey: apiKey,
      username: username,
    );
    pr!.then((v) {
      setState(() {
        print("pr reset");
        pr = null;
        var json = jsonDecode(v.responseBody);
        if (json["success"] == false) {
          print("_sendSearchAndUpdateState: Response failed: $json");
          if (json["reason"].contains("Access Denied")) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Access Denied. Did you mean to login?"),
            ));
          }
          posts = E6PostsSync(posts: []);
        } else {
          posts = svm.lazyLoad
              ? E6PostsLazy.fromJson(json as Map<String, dynamic>)
              : E6PostsSync.fromJson(json as Map<String, dynamic>);
        }
        if (posts?.posts.firstOrNull != null) {
          if (posts.runtimeType == E6PostsLazy) {
            (posts as E6PostsLazy)
                .onFullyIterated
                .subscribe((a) => getHasNextPage(
                      tags: priorSearchText,
                      lastPostId: a.posts.last.id,
                    ));
          } else {
            getHasNextPage(
                tags: priorSearchText,
                lastPostId: (posts as E6PostsSync).posts.last.id);
          }
        }
        if (isNewRequest) firstPostIdCached = firstPostOnPageId;
      });
    }).catchError((err, st) {
      print(err);
      print(st);
    });
  }
  // #endregion From WSearchView
}
