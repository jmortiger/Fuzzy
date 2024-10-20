import 'package:flutter/material.dart';
import 'package:fuzzy/intent.dart';
import 'package:fuzzy/main.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/tag_subscription.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/pages/tag_db_editor.dart';
import 'package:fuzzy/pages/user_profile_page.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/d_text_test_text.dart' as dtext;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/web/e621/search_helper.dart' as sh;
import 'package:fuzzy/widgets/w_comments_pane.dart';
import 'package:fuzzy/widgets/w_d_text_preview.dart';
import 'package:fuzzy/widgets/w_fab_builder.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart' as psr;
// import 'package:fuzzy/widgets/w_post_thumbnail.dart';
import 'package:fuzzy/widgets/w_update_set.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:fuzzy/widgets/w_search_pool.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:e621/e621.dart' as e621;
import 'package:j_util/j_util_widgets.dart' as w;
import 'package:provider/provider.dart';
import 'package:fuzzy/log_management.dart' as lm;

import '../web/e621/e621_access_data.dart';

class WHomeEndDrawer extends StatefulWidget {
  final void Function(String searchText)? onSearchRequested;

  /// For snackbars
  final BuildContext Function()? getMountedContext;

  const WHomeEndDrawer({
    super.key,
    this.onSearchRequested,
    this.getMountedContext,
  });

  @override
  State<WHomeEndDrawer> createState() => _WHomeEndDrawerState();
}

class _WHomeEndDrawerState extends State<WHomeEndDrawer> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WHomeEndDrawer");
  // #endregion Logger

  // ignore: deprecated_member_use_from_same_package
  /// It's better to directly check if [E621AccessData.userData] is assigned,
  /// but this forces the end drawer to rebuild when changed.
  bool isLoggedIn = false;
  // bool get isLoggedIn => E621AccessData.userData.isAssigned;
  @override
  void initState() {
    super.initState();
    isLoggedIn = E621AccessData.allowedUserDataSafe != null;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          !isLoggedIn
              ? const DrawerHeader(child: Text("Menu"))
              // : DrawerHeader(child: Text(E621AccessData.fallback?.username ?? "FAIL")),
              : WUserDrawerHeaderLoader(
                  data: E621AccessData.allowedUserDataSafe ??
                      E621AccessData.errorData,
                  user: E621.loggedInUser.$Safe,
                ),
          ListTile(
            title: const Text("Go to settings"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  )).then(
                (value) => AppSettings.i?.writeToFile(),
              );
            },
          ),
          ListTile(
            title:
                !isLoggedIn ? const Text("Login") : const Text("Change Login"),
            onTap: () => launchLogInDialog(context, widget.getMountedContext)
                .then((v) => (this.context.mounted)
                    ? setState(() {
                        isLoggedIn = true;
                      })
                    : ""),
            // onTap: () => launchLogInDialog(context, () => this.context)
            //     .then((v) => setState(() {})),
          ),
          // if (isLoggedIn)
          //   ListTile(
          //     title: const Text("Show User Profile"),
          //     onTap: () {
          //       Navigator.push(
          //           context,
          //           MaterialPageRoute(
          //             builder: (context) => UserProfilePageLoader.getByName(
          //                 username: E621AccessData.fallback!.username),
          //           ));
          //     },
          //   ),
          if (isLoggedIn)
            ListTile(
              title: const Text("Log out"),
              onTap: () {
                showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Log Out?"),
                      content: Text(
                        "Do you really want to log out of account "
                        "${E621AccessData.allowedUserDataSafe!.username}?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                              "Yes, and delete my username and API key"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Yes"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("No"),
                        ),
                      ],
                    );
                  },
                ).then((v) {
                  switch (v) {
                    case true:
                      E621AccessData.forcedUserDataSafe
                          ?.tryClearAsync()
                          .then((success) => this.context.mounted
                              ? util.showUserMessage(
                                  context: context,
                                  content: Text(
                                    success
                                        ? "Successfully cleared login data"
                                        : "Failed to clear login data",
                                  ),
                                )
                              : "");
                      continue falseC;
                    falseC:
                    case false:
                      E621AccessData.useLoginData = false;
                      break;
                    case null:
                    default:
                  }
                });
              },
            ),
          ListTile(
            title: const Text("Toggle Auth headers"),
            leading: E621AccessData.useLoginData
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            subtitle: Text(E621AccessData.useLoginData ? "On" : "Off"),
            onTap: () {
              print("Before: ${E621AccessData.useLoginData}");
              setState(() => E621AccessData.toggleUseLoginData()
                  /* () => Provider.of<SearchViewModel>(context, listen: false)
                        .toggleSendAuthHeaders(), */
                  ); // Just to trigger rebuild
              print("After: ${E621AccessData.useLoginData}");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Image Display Method"),
            onTap: () {
              logger.fine("Before: ${imageFit.name}");
              setState(() {
                imageFit =
                    imageFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
              });
              logger.fine("After: ${imageFit.name}");
              // Navigator.pop(context);
            },
            trailing: Text(imageFit.name),
          ),
          ListTile(
            title: const Text("Search sets"),
            leading: const Icon(Icons.search),
            onTap: () {
              logger.finer("Search Set activated");
              Navigator.pop(context);
              /* showDialog<e621.PostSet>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    content: WSearchSet(
                      initialLimit: 10,
                      initialPage: null,
                      initialSearchCreatorName:
                          E621AccessData.fallback?.username,
                      initialSearchOrder: e621.SetOrder.updatedAt,
                      initialSearchName: null,
                      initialSearchShortname: null,
                      onSelected: (e621.PostSet set) =>
                          Navigator.pop(ctx, set),
                    ),
                    // scrollable: true,
                  );
                },
              ) */
              Navigator.push(
                context,
                MaterialPageRoute<e621.PostSet>(
                  builder: (ctx) => WSearchSet(
                    isFullPage: true,
                    initialLimit: 10,
                    initialPage: null,
                    initialSearchCreatorName:
                        E621AccessData.allowedUserDataSafe?.username,
                    initialSearchOrder: e621.SetOrder.updatedAt,
                    initialSearchName: null,
                    initialSearchShortname: null,
                    // onSelected: (_) => "",
                    onSelected: (e621.PostSet set) => Navigator.pop(ctx, set),
                    // onMultiselectCompleted: (_) => "",
                  ),
                ),
                // Navigator.pushNamed<dynamic>(
                //   context,
                //   Uri.parse(SearchSetRoute.routePathConst).replace(queryParameters: {
                //     "search[creator_name]":E621AccessData.allowedUserDataSafe?.username,
                //     "limit":"10",
                //     "search[order]":e621.SetOrder.updatedAt.query,
                //   }).toString(),
                //   /* MaterialPageRoute<e621.PostSet>(
                //     builder: (ctx) => WSearchSet(
                //       isFullPage: true,
                //       initialLimit: 10,
                //       initialSearchCreatorName:
                //           E621AccessData.allowedUserDataSafe?.username,
                //       initialSearchOrder: e621.SetOrder.updatedAt,
                //       // onSelected: (_) => "",
                //       onSelected: (e621.PostSet set) => Navigator.pop(ctx, set),
                //       // onMultiselectCompleted: (_) => "",
                //     ),
                //   ), */
              ).then((v) => v != null
                  ? widget.onSearchRequested?.call(
                      SearchView.i.preferSetShortname
                          ? v.searchByShortname
                          : v.searchById)
                  : null);
            },
          ),
          ListTile(
            title: const Text("Search pools"),
            leading: const Icon(Icons.search),
            onTap: () {
              print("Search Pool activated");
              Navigator.pop(context);
              showDialog<e621.Pool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    content: WSearchPool(
                      initialLimit: 10,
                      initialSearchOrder: e621.PoolOrder.updatedAt,
                      initialSearchNameMatches: null,
                      onSelected: (e621.Pool pool) =>
                          Navigator.pop(context, pool),
                    ),
                    // scrollable: true,
                  );
                },
              ).then((v) => v != null
                  ? widget.onSearchRequested?.call(v.searchById)
                  : null);
            },
          ),
          ListTile(
            title: const Text("Create set"),
            leading: const Icon(Icons.add),
            onTap: () {
              print("Create Set activated");
              Navigator.pop(context);
              showDialog<e621.PostSet>(
                context: context,
                builder: (_) {
                  return const AlertDialog(
                    content:
                        w.SoloBackButton.noOverlay(child: WUpdateSet.create()),
                    // scrollable: true,
                  );
                },
              ) /* .then((v) => v != null
                  ? widget.onSearchRequested?.call(
                      SearchView.i.preferSetShortname
                          ? v.searchByShortname
                          : v.searchById)
                  : null) */
                  ;
            },
          ),
          if (isLoggedIn)
            ListTile(
              title: const Text("Search deleted favs"),
              leading: const Icon(Icons.search),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => buildHomePageWithProviders(
                          searchText:
                              "fav:${E621.loggedInUser.$Safe?.name ?? E621AccessData.forcedUserDataSafe?.username} status:deleted"),
                    ));
              },
            ),
          if (isLoggedIn)
            ListTile(
              title: const Text("Search Favs (Order Preserved)"),
              leading: const Icon(Icons.search),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => buildWithProviders(
                              mpcProvider: ChangeNotifierProvider(
                                  create: (_) => FavoritesCollectionLoader()),
                              builder: (context, _) => Scaffold(
                                appBar: AppBar(
                                  title: Text(
                                      "${E621.loggedInUser.$Safe?.name}'s Favorites"),
                                ),
                                body: SafeArea(
                                    child: psr.WPostSearchResultsSwiper
                                        .buildItFull(context)),
                                /* body: Column(
                                  children: [
                                    Selector<ManagedPostCollectionSync, String>(
                                      builder: (_, value, __) => Expanded(
                                          key: ObjectKey(value),
                                          child: psr.WPostSearchResultsSwiper(
                                            useLazyBuilding:
                                                SearchView.i.lazyBuilding,
                                          )),
                                      selector: (ctx, p1) => p1.parameters.tags,
                                    ),
                                  ],
                                ), */
                                floatingActionButton:
                                    WFabBuilder.buildItFull(context),
                              ),
                            )));
              },
            ),
          ListTile(
            title: const Text("View Subscriptions"),
            leading: const Icon(Icons.search),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionPage(),
                  ));
            },
          ),
          ListTile(
            title: const Text("Try load"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              if (!checkAndLaunch(context)) {
                util.showUserMessage(
                  context: context,
                  content: const Text("No page to load"),
                );
              }
            },
          ),
          ListTile(
            title: const Text("Help"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              );
            },
          ),
          ListTile(
            title: const Text("Tag DB Editing"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TagDbEditorPage()),
              );
            },
          ),
          ListTile(
            title: const Text("Test DText"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                        content: SizedBox(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          child: w.SoloBackButton.noOverlay(
                              child: WDTextPreviewScrollable(
                            initialText: dtext.testText,
                            maxLines: 5,
                          )),
                        ),
                      ));
            },
          ),
          ListTile(
            title: const Text("Test Comment"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                        content: SizedBox(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          child: w.SoloBackButton.noOverlay(
                              child: FutureBuilder(
                                  future: e621.sendRequest(util
                                          .devData.isAssigned
                                      ? e621.initGetCommentRequest(
                                          id: util
                                                  .devData
                                                  .$Safe?["e621"]["comments"]
                                                  .first ??
                                              3)
                                      : e621.initSearchCommentsRequest(
                                          limit: 1)),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return WComment(
                                        comment: e621.Comment.fromRawJson(
                                          snapshot.data!.body,
                                        ),
                                      );
                                    } else {
                                      return const AspectRatio(
                                        aspectRatio: 1,
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  })),
                        ),
                      ));
            },
          ),
          ListTile(
            title: const Text("Test Comments"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                        content: SizedBox(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          child: w.SoloBackButton.noOverlay(
                              child: FutureBuilder(
                                  future: e621
                                      .sendRequest(
                                        util.devData.isAssigned
                                            ? e621.initSearchCommentsRequest(
                                                searchPostId: util.devData
                                                            .$Safe?["e621"]
                                                        ["posts"]["comments"] ??
                                                    14,
                                              )
                                            : e621.initSearchCommentsRequest(
                                                searchPostId: 1699321,
                                              ),
                                      )
                                      .then((v) => v.body),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return WCommentsPane(
                                        comments:
                                            e621.Comment.fromRawJsonResults(
                                                snapshot.data!),
                                      );
                                    } else {
                                      return const AspectRatio(
                                        aspectRatio: 1,
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                  })),
                        ),
                      ));
            },
          ),
          ListTile(
            title: const Text("Test Comments Loader"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                          content: SizedBox(
                        width: double.maxFinite,
                        height: double.maxFinite,
                        child: w.SoloBackButton.noOverlay(
                            child: SingleChildScrollView(
                          child: WCommentsLoader(
                            postId: util.devData.$Safe?["e621"]["posts"]
                                    ["comments2"] ??
                                1699321,
                          ),
                        )),
                      )));
            },
          ),
          ListTile(
            title: const Text("Test Search MetaTag parsing"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                        content: SizedBox(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          child: w.SoloBackButton.noOverlay(
                            child: (() {
                              var inputText = "",
                                  mts = sh.MetaTagSearchData.fromSearchString(
                                      inputText);
                              strip() => sh.removeMetaTags(inputText);
                              stripMatched() =>
                                  mts.removeMatchedMetaTags(inputText);
                              return StatefulBuilder(
                                builder: (context, setState) => Column(
                                  children: [
                                    const Text("MetaTag String"),
                                    Text(mts.toString()),
                                    const Text("String stripped of metatags"),
                                    Text(strip()),
                                    const Text("Resultant Search"),
                                    Text("${strip()}${mts.toString()}"),
                                    const Text(
                                        "String stripped of matched metatags"),
                                    Text(stripMatched()),
                                    const Text("Resultant Search"),
                                    Text("${stripMatched()}${mts.toString()}"),
                                    TextField(
                                      onChanged: (value) => setState(
                                        () => mts = sh.MetaTagSearchData
                                            .fromSearchString(
                                                inputText = value),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })(),
                          ),
                        ),
                      ));
            },
          ),
          ListTile(
            title: const Text("Toggle Use Fab"),
            leading: w.SelectorNotifier(
              value: useFab,
              selector: (_, v) => v.value,
              builder: (_, useFabState, __) => useFabState
                  ? const Icon(Icons.check_box)
                  : const Icon(Icons.check_box_outline_blank),
            ),
            onTap: () {
              print("Before: ${useFab.value}");
              () => useFab.value = !useFab.value;
              print("After: ${useFab.value}");
            },
          ),
        ],
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help")),
      body: const SafeArea(
        child: Column(
          children: [
            Text("If no posts are selected, tap on a post to view it."),
            Text("If no posts are selected, tap and hold on a post to select."),
            Text("If posts are selected, tap on a post to select/deselect."),
            Text("If posts are selected, tap and hold on a post to view it."),
            Text("Selections carry over between pages."),
            Text("You can clear selections by using the floating button."),
            Text("The floating button is disabled when no posts are selected."),
          ],
        ),
      ),
    );
  }
}

class WUserDrawerHeader extends StatelessWidget {
  final E621AccessData data;

  final e621.User? user;
  e621.UserDetailed? get userD =>
      user is e621.UserDetailed ? user as e621.UserDetailed : null;
  e621.UserLoggedIn? get userL =>
      user is e621.UserLoggedIn ? user as e621.UserLoggedIn : null;
  const WUserDrawerHeader({
    super.key,
    required this.data,
    required this.user,
  });

  static Widget createUsernameDisplay(E621AccessData data, e621.User? user) =>
      Text(user?.name ?? data.username);
  static Widget buildShell(BuildContext context, E621AccessData data,
          e621.User? user, Widget root) =>
      DrawerHeader(
        child: InkWell(
          onTap: user == null
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfilePageLoader.getByName(
                        username: data.username),
                  ))
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfilePageLoader.getById(id: user.id),
                  )),
          child: root,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final root = Column(
      children: [
        // if (user?.avatarId != null)
        //   WPostThumbnail.withId(id: user!.avatarId!),
        createUsernameDisplay(data, user),
        if (userL != null) UserProfilePage.generateFavStatsFull(userL!),
        // Text("FavCount: ${userL!.favoriteCount}/${userL!.favoriteLimit}"
        //     " (${userL!.favoriteLimit - userL!.favoriteCount} left)"),
        if (userL != null) Text("Tag Query Limit: ${userL!.tagQueryLimit}"),
      ],
    );
    return buildShell(context, data, user, root);
  }
}

class WUserDrawerHeaderLoader extends StatefulWidget {
  final E621AccessData data;

  final e621.User? user;
  const WUserDrawerHeaderLoader({
    super.key,
    required this.data,
    required this.user,
  });

  @override
  State<WUserDrawerHeaderLoader> createState() =>
      _WUserDrawerHeaderLoaderState();
}

class _WUserDrawerHeaderLoaderState extends State<WUserDrawerHeaderLoader> {
  static lm.FileLogger get logger => _WHomeEndDrawerState.logger;
  e621.User? user;

  Future<e621.User?>? userFuture;

  e621.UserDetailed? get userD =>
      user is e621.UserDetailed ? user as e621.UserDetailed : null;

  e621.UserLoggedIn? get userL =>
      user is e621.UserLoggedIn ? user as e621.UserLoggedIn : null;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    if (widget.user == null || widget.user is! e621.UserDetailed) {
      final t = E621.retrieveUserMostSpecific(user: user, data: widget.data);
      if (t is Future<e621.User?>?) {
        userFuture = t?.then((v) {
          setState(() {
            user = v;
            userFuture = null;
          });
          E621.tryUpdateLoggedInUser(user);
          return v;
        })
          ?..ignore();
      } else {
        logger.warning("Unexpected failure retrieving "
            "User in _WUserDrawerHeaderLoaderState.initState");
        assert(t is! Future);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return userFuture == null
        ? WUserDrawerHeader(data: widget.data, user: user)
        : WUserDrawerHeader.buildShell(
            context,
            widget.data,
            user,
            Column(
              children: [
                WUserDrawerHeader.createUsernameDisplay(widget.data, user),
                const CircularProgressIndicator(),
              ],
            ));
    // DrawerHeader(
    //     child: Column(
    //       children: [
    //         WUserDrawerHeader.createUsernameDisplay(widget.data, user),
    //         const CircularProgressIndicator(),
    //       ],
    //     ),
    //   );
  }
}
