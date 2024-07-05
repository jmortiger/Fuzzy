// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/search_view_model.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_image_result.dart';
import 'package:fuzzy/widgets/w_search_pool.dart';
import 'package:fuzzy/widgets/w_search_set.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:provider/provider.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;

late final lRecord = lm.genLogger("WHomeEndDrawer");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

class WHomeEndDrawer extends StatefulWidget {
  final void Function(String searchText)? onSearchRequested;

  const WHomeEndDrawer({super.key, this.onSearchRequested});

  @override
  State<WHomeEndDrawer> createState() => _WHomeEndDrawerState();
}

class _WHomeEndDrawerState extends State<WHomeEndDrawer> {
  SearchViewModel get svm =>
      Provider.of<SearchViewModel>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text("Menu"),
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
            title: !E621AccessData.userData.isAssigned
                ? const Text("Login")
                : const Text("Change Login"),
            onTap: () {
              showDialog<({String username, String apiKey})>(
                context: context,
                builder: (context) {
                  String username = "", apiKey = "";
                  return AlertDialog(
                    title: const Text("Login"),
                    content: Column(
                      children: [
                        TextField(
                          onChanged: (value) => username = value,
                          decoration: const InputDecoration(
                            label: Text("Username"),
                            hintText: "Username",
                          ),
                        ),
                        TextField(
                          onChanged: (value) => apiKey = value,
                          decoration: const InputDecoration(
                            label: Text("API Key"),
                            hintText: "API Key",
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        // onPressed: () => Navigator.pop(context, t),
                        onPressed: () => Navigator.pop(
                            context, (username: username, apiKey: apiKey)),
                        child: const Text("Accept"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text("Cancel"),
                      ),
                    ],
                  );
                },
              ).then((v) {
                if (v != null) {
                  E621AccessData.userData.$ = E621AccessData.withDefault(
                      apiKey: v.apiKey, username: v.username);
                  E621AccessData.tryWrite().then<void>((v) {
                    if (v) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Successfully stored! Test it!"),
                          action: SnackBarAction(
                            label: "See Contents",
                            onPressed: () async => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: Text(E621AccessData
                                        .userData.itemSafe?.file.itemSafe
                                        ?.readAsStringSync() ??
                                    ""),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  });
                }
              });
            },
          ),
          if (E621AccessData.userData.isAssigned)
            ListTile(
              title: const Text("Show User Profile"),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog();
                  },
                );
              },
            ),
          ListTile(
            title: const Text("Toggle Lazy Loading"),
            leading:
                Provider.of<SearchViewModel>(context, listen: false).lazyLoad
                    ? const Icon(Icons.check_box)
                    : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print(
                  "Before: ${Provider.of<SearchViewModel>(context, listen: false)}.lazyLoad");
              setState(() =>
                  Provider.of<SearchViewModel>(context, listen: false)
                      .toggleLazyLoad());
              print(
                  "After: ${Provider.of<SearchViewModel>(context, listen: false)}.lazyLoad");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Lazy Building"),
            leading: Provider.of<SearchViewModel>(context, listen: false)
                    .lazyBuilding
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print(
                  "Before: ${Provider.of<SearchViewModel>(context, listen: false)}.lazyBuilding");
              setState(() =>
                  Provider.of<SearchViewModel>(context, listen: false)
                      .toggleLazyBuilding());
              print(
                  "After: ${Provider.of<SearchViewModel>(context, listen: false)}.lazyBuilding");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Auth headers"),
            leading: Provider.of<SearchViewModel>(context, listen: false)
                    .sendAuthHeaders
                ? const Icon(Icons.check_box)
                : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print(
                  "Before: ${Provider.of<SearchViewModel>(context, listen: false)}.sendAuthHeaders");
              setState(() =>
                  Provider.of<SearchViewModel>(context, listen: false)
                      .toggleSendAuthHeaders());
              print(
                  "After: ${Provider.of<SearchViewModel>(context, listen: false)}.sendAuthHeaders");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Force Safe"),
            leading:
                Provider.of<SearchViewModel>(context, listen: false).forceSafe
                    ? const Icon(Icons.check_box)
                    : const Icon(Icons.check_box_outline_blank),
            onTap: () {
              print(
                  "Before: ${Provider.of<SearchViewModel>(context, listen: false)}.forceSafe");
              setState(() =>
                  Provider.of<SearchViewModel>(context, listen: false)
                      .toggleForceSafe());
              print(
                  "After: ${Provider.of<SearchViewModel>(context, listen: false)}.forceSafe");
              // Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text("Toggle Image Display Method"),
            onTap: () {
              print("Before: ${imageFit.name}");
              imageFit =
                  imageFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
              print("After: ${imageFit.name}");
              // Navigator.pop(context);
            },
            trailing: Text(imageFit.name),
          ),
          ListTile(
            title: const Text("Search sets"),
            leading: const Icon(Icons.search),
            onTap: () {
              print("_WHomeEndDrawerState.build: Search Set activated");
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
                  ? widget.onSearchRequested?.call(v.searchById)
                  : null);
            },
          ),
          ListTile(
            title: const Text("Search pools"),
            leading: const Icon(Icons.search),
            onTap: () {
              print("_WHomeEndDrawerState.build: Search Pool activated");
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
        ],
      ),
    );
  }
}
