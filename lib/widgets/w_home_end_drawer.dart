import 'package:flutter/material.dart';
import 'package:fuzzy/domain_verification_page.dart';
import 'package:fuzzy/intent.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/pages/user_profile_page.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/widgets/w_back_button.dart';
import 'package:fuzzy/widgets/w_update_set.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:fuzzy/widgets/w_search_pool.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:j_util/e621.dart' as e621;
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
  static late final lRecord = lm.generateLogger("WHomeEndDrawer");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
  SearchViewModel get svm =>
      Provider.of<SearchViewModel>(context, listen: false);

  /// It's better to directly check if [E621AccessData.userData] is assigned,
  /// but this forces the end drawer to rebuild when changed.
  bool isLoggedIn = false;
  // bool get isLoggedIn => E621AccessData.userData.isAssigned;
  @override
  void initState() {
    super.initState();
    isLoggedIn = E621AccessData.fallback != null;
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
                  data: E621AccessData.fallback ?? E621AccessData.errorData,
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
                (value) => AppSettings.writeSettingsToFile(),
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
          //             builder: (context) => UserProfileLoaderPage.getByName(
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
                        "${E621AccessData.fallback!.username}?",
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
                      E621AccessData.userData.$Safe?.tryClearAsync().then(
                          (success) => this.context.mounted
                              ? ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                      content: Text(success
                                          ? "Successfully cleared login data"
                                          : "Failed to clear login data")))
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
          // ListTile(
          //   title: const Text("Toggle Lazy Loading"),
          //   leading:
          //       Provider.of<SearchViewModel>(context, listen: false).lazyLoad
          //           ? const Icon(Icons.check_box)
          //           : const Icon(Icons.check_box_outline_blank),
          //   onTap: () {
          //     print(
          //         "Before: ${Provider.of<SearchViewModel>(context, listen: false).lazyLoad}");
          //     setState(() =>
          //         Provider.of<SearchViewModel>(context, listen: false)
          //             .toggleLazyLoad());
          //     print(
          //         "After: ${Provider.of<SearchViewModel>(context, listen: false).lazyLoad}");
          //     // Navigator.pop(context);
          //   },
          // ),
          // ListTile(
          //   title: const Text("Toggle Lazy Building"),
          //   leading: SearchView.i.lazyBuilding
          //       ? const Icon(Icons.check_box)
          //       : const Icon(Icons.check_box_outline_blank),
          //   onTap: () {
          //     print("Before: ${SearchView.i.lazyBuilding}");
          //     setState(
          //         () => SearchView.i.lazyBuilding = !SearchView.i.lazyBuilding);
          //     print("After: ${SearchView.i.lazyBuilding}");
          //     // Navigator.pop(context);
          //   },
          // ),
          ListTile(
            title: const Text("Toggle Auth headers"),
            leading: E621AccessData.useLoginData
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            subtitle: Text(E621AccessData.useLoginData ? "On" : "Off"),
            onTap: () {
              print("Before: ${E621AccessData.useLoginData}");
              setState(
                () => //E621AccessData.toggleUseLoginData
                    Provider.of<SearchViewModel>(context, listen: false)
                        .toggleSendAuthHeaders(),
              ); // Just to trigger rebuild
              print("After: ${E621AccessData.useLoginData}");
              // Navigator.pop(context);
            },
          ),
          // ListTile(
          //   title: const Text("Toggle Force Safe"),
          //   leading:
          //       Provider.of<SearchViewModel>(context, listen: false).forceSafe
          //           ? const Icon(Icons.check_box)
          //           : const Icon(Icons.check_box_outline_blank),
          //   onTap: () {
          //     print(
          //         "Before: ${Provider.of<SearchViewModel>(context, listen: false).forceSafe}");
          //     setState(() =>
          //         Provider.of<SearchViewModel>(context, listen: false)
          //             .toggleForceSafe());
          //     print(
          //         "After: ${Provider.of<SearchViewModel>(context, listen: false).forceSafe}");
          //     // Navigator.pop(context);
          //   },
          // ),
          ListTile(
            title: const Text("Toggle Image Display Method"),
            onTap: () {
              print("Before: ${imageFit.name}");
              setState(() {
                imageFit =
                    imageFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
              });
              print("After: ${imageFit.name}");
              // Navigator.pop(context);
            },
            trailing: Text(imageFit.name),
          ),
          ListTile(
            title: const Text("Search sets"),
            leading: const Icon(Icons.search),
            onTap: () {
              print("Search Set activated");
              Navigator.pop(context);
              showDialog<e621.PostSet>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    content: WSearchSet(
                      initialLimit: 10,
                      initialPage: null,
                      initialSearchCreatorName: E621AccessData.fallback?.username,
                      initialSearchOrder: e621.SetOrder.updatedAt,
                      initialSearchName: null,
                      initialSearchShortname: null,
                      onSelected: (e621.PostSet set) =>
                          Navigator.pop(context, set),
                    ),
                    // scrollable: true,
                  );
                },
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
                builder: (context) {
                  return const AlertDialog(
                    content:
                        WBackButton.doNotBlockChild(child: WUpdateSet.create()),
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
          ListTile(
            title: const Text("Linking test"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DomainVerificationPage(),
                  ));
            },
          ),
          ListTile(
            title: const Text("Try load"),
            leading: const Icon(Icons.question_mark),
            onTap: () {
              Navigator.pop(context);
              if (!checkAndLaunch(context)) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text("No page to load")),
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
                MaterialPageRoute(builder: (context) => const HelpPage()),
              );
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
              ? () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileLoaderPage.getByName(
                            username: data.username),
                      ));
                }
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserProfileLoaderPage.getById(id: user.id),
                  )),
          child: root,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final root = Column(
      children: [
        createUsernameDisplay(data, user),
        if (userL != null) UserProfilePage.generateFavStats(userL!),
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
