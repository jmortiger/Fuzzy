import 'package:flutter/material.dart';
import 'package:fuzzy/domain_verification_page.dart';
import 'package:fuzzy/intent.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/pages/user_profile_page.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/widgets/w_back_button.dart';
import 'package:fuzzy/widgets/w_create_set.dart';
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
    isLoggedIn =
        E621AccessData.userData.isAssigned && E621AccessData.useLoginData;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          !isLoggedIn
              ? const DrawerHeader(child: Text("Menu"))
              // : DrawerHeader(child: Text(E621AccessData.fallback?.username ?? "FAIL")),
              : DrawerHeader(
                  child:
                      Text(E621AccessData.userData.$Safe?.username ?? "FAIL")),
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
          if (isLoggedIn)
            ListTile(
              title: const Text("Show User Profile"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileLoaderPage.getByName(
                          username: E621AccessData.userData.$Safe?.username ??
                              E621AccessData.devAccessData.$.username),
                    ));
              },
            ),
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
                      initialSearchCreatorName: "***REMOVED***,
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
                      // initialSearchCreatorName: "***REMOVED***,
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
                    content: WBackButton.doNotBlockChild(child: WCreateSet()),
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
              checkAndLaunch(context);
            },
          ),
        ],
      ),
    );
  }
}
