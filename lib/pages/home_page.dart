// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:http/http.dart' as http;
import 'package:fuzzy/web/models/e621/e6_models.dart';
import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:fuzzy/web/site.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';
import 'package:fuzzy/util/util.dart' as util;

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool openMenu = false;
  bool toggleMenu() => openMenu = !openMenu;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fuzzy"),
      ),
      body: SafeArea(
        child: buildSearchView(context),
      ),
      endDrawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text("Menu"),
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
                setState(() => toggleMenu());
              },
            ),
            ListTile(
              title: const Text("Toggle Auth headers"),
              leading: sendAuthHeaders
                  ? const Icon(Icons.check_box)
                  : const Icon(Icons.check_box_outline_blank),
              onTap: () {
                print("Before: $sendAuthHeaders");
                setState(() => toggleSendAuthHeaders());
                print("After: $sendAuthHeaders");
                setState(() => toggleMenu());
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
                setState(() => toggleMenu());
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
                setState(() => toggleMenu());
              },
            ),
          ],
        ),
      ),
    );
  }

  // #region From WSearchView
  bool lazyLoad = false;
  bool toggleLazyLoad() => lazyLoad = !lazyLoad;
  bool tagSafety = false;
  bool toggleTagSafety() => tagSafety = !tagSafety;
  bool sendAuthHeaders = false;
  bool toggleSendAuthHeaders() => sendAuthHeaders = !sendAuthHeaders;
  bool forceSafe = true;
  bool toggleForceSafe() => forceSafe = !forceSafe;
  String searchText = "";
  Future<http.StreamedResponse>? pr;
  int? currentPostCollectionExpectedSize;
  E6Posts? posts;

  @widgetFactory
  Widget buildSearchView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: simpleTextField(),
          // child: autoCompleteTextField(),
        ),
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
            pr = null;
            return Expanded(
              child: WPostSearchResults(
                posts: posts!,
                expectedCount: lazyLoad
                    ? (currentPostCollectionExpectedSize ?? 50)
                    : posts!.count,
                searchText: searchText,
              ),
            );
          })()
      ],
    );
  }

  @widgetFactory
  Autocomplete<TagDBEntry> autoCompleteTextField() {
    return Autocomplete<TagDBEntry>(
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        void Function() onFieldSubmitted,
      ) =>
          TextField(
        controller: textEditingController,
        focusNode: focusNode,
        onChanged: (value) => setState(() => searchText = value),
        onSubmitted: (s) => setState(() {
          onFieldSubmitted();
          searchText = textEditingController.text;
          if (searchText.isNotEmpty) {
            _sendAndSetRequest(tags: searchText);
          } else {
            _sendAndSetRequest();
          }
        }),
      ),
      optionsBuilder: (TextEditingValue textEditingValue) {
        var db = !util.DO_NOT_USE_TAG_DB ? util.tagDbLazy.itemSafe : null;
        if (db == null || textEditingValue.text.isEmpty) {
          return const Iterable<TagDBEntry>.empty();
        }
        var (s, e) = db.getCharStartAndEnd(textEditingValue.text[0]);
        print("range For ${textEditingValue.text[0]}: $s - $e");
        if (textEditingValue.text.length == 1) {
          return db.tagsByString.queue.getRange(s, e).toList(growable: false)
            ..sort((a, b) => b.postCount - a.postCount);
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
        if (s1 == -1) return const Iterable<TagDBEntry>.empty();
        var e1 = t.lastIndexWhere(
            (element) => element.name.startsWith(textEditingValue.text));
        if (e1 == -1) {
          e1 = t.lastIndexWhere((element) =>
              element.name.startsWith(textEditingValue.text.substring(
                0,
                textEditingValue.text.length - 1,
              )));
        }
        if (e1 == -1) return const Iterable<TagDBEntry>.empty();
        return t.getRange(s1, e1).toList(growable: false)
          ..sort((a, b) => b.postCount - a.postCount);
      },
      displayStringForOption: (option) => option.name,
      onSelected: (option) => setState(() {
        searchText += option.name;
      }),
    );
  }

  @widgetFactory
  TextField simpleTextField() {
    return TextField(
      autofillHints: const [AutofillHints.url],
      autofocus: true,
      enableSuggestions: true,
      onChanged: (value) => setState(() => searchText = value),
      onSubmitted: (value) => setState(() {
        _sendAndSetRequest(tags: value);
      }),
    );
  }

  http.Request deliverSearchRequest({
    String tags = "jun_kobayashi",
    int limit = 50,
    String? page,
  }) {
    currentPostCollectionExpectedSize = limit;
    return E621ApiEndpoints.searchPosts.getMoreData().genRequest(
        query: {
          "limit": (0, {"LIMIT": limit}),
          "tags": (0, {"SEARCH_STRING": tags}),
        },
        headers: sendAuthHeaders
            ? {
                "Authorization": (
                  0,
                  {
                    "USERNAME": E621AccessData.myUsername,
                    "API_KEY": E621AccessData.myApiKey,
                  }
                ),
              }
            : null);
  }

  void _sendAndSetRequest({
    String tags = "jun_kobayashi",
    int limit = 50,
    String? page,
  }) {
    pr = deliverSearchRequest(tags: forceSafe ? "$tags rating:safe" : tags, limit: limit, page: page).send();
    pr!.then((value) {
      value.stream.bytesToString().then((value) {
        setState(() {
          pr = null;
          posts = lazyLoad
              ? E6PostsLazy.fromJson(json.decode(value) as Map<String, dynamic>)
              : E6PostsSync.fromJson(
                  json.decode(value) as Map<String, dynamic>);
        });
      });
    });
  }
  // #endregion From WSearchView
}
