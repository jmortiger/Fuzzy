import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/main.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dtext;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:e621/e621.dart';

import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/widgets/w_post_thumbnail.dart';

import '../web/e621/e621_access_data.dart';

class UserProfilePage extends StatelessWidget with IRoute<UserProfilePage> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("UserProfilePage").logger;
  // #region Routing
  static const routeNameConst = "/users",
      routeSegmentsConst = ["users", IRoute.idPathParameter],
      routePathConst = "/users/${IRoute.idPathParameter}",
      hasStaticPathConst = false;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;

  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) {
    final id = IRoute.decodePathParameter<int>(
      settings,
      routeSegmentsConst,
      hasStaticPathConst,
    );
    if (id == null) {
      routeLogger.severe(
        "Routing failure: no id\n"
        "\tRoute: ${settings.name}\n"
        "\tId: $id\n"
        "\tArgs: ${settings.arguments}",
      );
      throw StateError("Routing failure: no id\n"
          "\tRoute: ${settings.name}\n"
          "\tId: $id\n"
          "\tArgs: ${settings.arguments}");
    }
    final rp = RouteParameterResolver.fromDynamic(settings.arguments),
        user = rp.user,
        username = rp.username;
    return UserProfilePageLoader(id: id, user: user, username: username);
  }
  // #endregion Routing

  final User user;
  final UserDetailedMixin? userD;
  final CurrentUser? userL;

  const UserProfilePage({
    super.key,
    required this.user,
  })  : userD = user is UserDetailed ? user : null,
        userL = user is UserLoggedIn ? user : null;
  static Widget generateFavStats(UserLoggedIn userL) => Text.rich(TextSpan(
        text: "FavCount: ${userL.favoriteCount}/${userL.favoriteLimit} (",
        children: [
          TextSpan(
              text: "${userL.favoriteLimit - userL.favoriteCount}",
              style: TextStyle(
                color: switch (userL.favoriteLimit - userL.favoriteCount) {
                  >= 500 => Colors.green,
                  >= 100 && < 500 => Colors.amber,
                  < 100 => Colors.red,
                  _ => throw UnsupportedError("value not supported"),
                },
                fontWeight: FontWeight.bold,
              )),
          const TextSpan(text: " left)"),
        ],
      ));
  static Widget generateFavStatsFull(CurrentUser userL, [int? deletedFavs]) =>
      deletedFavs != null
          ? Text.rich(TextSpan(
              text: "FavCount: ${userL.favoriteCount}/${userL.favoriteLimit} (",
              children: [
                TextSpan(
                    text: "${userL.favoriteLimit - userL.favoriteCount}",
                    style: TextStyle(
                      color: switch (
                          userL.favoriteLimit - userL.favoriteCount) {
                        >= 500 => Colors.green,
                        >= 100 && < 500 => Colors.amber,
                        < 100 => Colors.red,
                        _ => throw UnsupportedError("value not supported"),
                      },
                      fontWeight: FontWeight.bold,
                    )),
                TextSpan(text: " left; $deletedFavs deleted)"),
              ],
            ))
          : FutureBuilder(
              future: E621
                  .getDeletedFavsAsync() /* E621.findTotalPostNumber(
                  tags: "fav:${userL.name} status:deleted") */
              ,
              builder: (context, snapshot) => Text.rich(TextSpan(
                    text:
                        "FavCount: ${userL.favoriteCount}/${userL.favoriteLimit} (",
                    children: [
                      TextSpan(
                          text: "${userL.favoriteLimit - userL.favoriteCount}",
                          style: TextStyle(
                            color: switch (
                                userL.favoriteLimit - userL.favoriteCount) {
                              >= 500 => Colors.green,
                              >= 100 && < 500 => Colors.amber,
                              < 100 => Colors.red,
                              _ =>
                                throw UnsupportedError("value not supported"),
                            },
                            fontWeight: FontWeight.bold,
                          )),
                      TextSpan(
                          text:
                              " left; ${snapshot.hasData ? snapshot.data! : "..."} deleted)"),
                    ],
                  )));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "User ${user.id}: ${user.name}${user is UserLoggedIn ? " (You)" : ""}",
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.avatarId != null)
              WPostThumbnail.withId(id: user.avatarId!),
            Text("Created At: ${user.createdAt}"),
            Text("Level: ${user.levelString}(${user.level})"),
            if (userD != null)
              ExpansionTile(
                  title: const Text("ProfileAbout"),
                  children: [Text.rich(dtext.parse(userD!.profileAbout))]),
            if (userD != null) Text("ProfileArtInfo: ${userD!.profileArtInfo}"),
            if (userD != null)
              Text("Post Update Count: ${user.postUpdateCount}"),
            Text("Post Upload Count: ${user.postUploadCount}"),
            Text("Note Update Count: ${user.noteUpdateCount}"),
            Text("Is Banned: ${user.isBanned}"),
            Text("Can Approve Posts: ${user.canApprovePosts}"),
            Text("Can Upload Free: ${user.canUploadFree}"),
            Text("Base Upload Limit: ${user.baseUploadLimit}"),
            if (userL != null) generateFavStatsFull(userL!),
            if (userL != null) Text("Tag Query Limit: ${userL!.tagQueryLimit}"),
            if (userL != null)
              Text("Blacklist Users: ${userL!.blacklistUsers}"),
            if (userL != null)
              Text("Blacklisted Tags: ${userL!.blacklistedTags}"),
            if (userL != null) Text("Favorite Tags: ${userL!.favoriteTags}"),
            if (userL != null) Text("Api Burst Limit: ${userL!.apiBurstLimit}"),
            if (userL != null)
              Text("API Regen Multiplier: ${userL!.apiRegenMultiplier}"),
            if (userL != null)
              Text("Remaining API Limit: ${userL!.remainingApiLimit}"),
            if (userD != null) ...[
              Text("Artist Version Count: ${userD!.artistVersionCount}"),
              Text("Comment Count: ${userD!.commentCount}"),
              Text("Favorite Count: ${userD!.favoriteCount}"),
              Text("Flag Count: ${userD!.flagCount}"),
              Text("Forum Post Count: ${userD!.forumPostCount}"),
              UserFeedbackCount(user: userD!),
              Text("Pool Version Count: ${userD!.poolVersionCount}"),
              Text("Upload Limit: ${userD!.uploadLimit}"),
              Text("Wiki Page Version Count: ${userD!.wikiPageVersionCount}"),
            ]
          ],
        ),
      ),
    );
  }
}

class UserFeedbackCount extends StatelessWidget {
  final UserDetailedMixin user;
  const UserFeedbackCount({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(text: "Feedback Count: ", children: [
      const TextSpan(
          text: "↑",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      TextSpan(text: ": ${user.positiveFeedbackCount} | "),
      const TextSpan(
          text: "-",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      TextSpan(text: ": ${user.neutralFeedbackCount} | "),
      const TextSpan(
          text: "↓",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      TextSpan(text: ": ${user.negativeFeedbackCount}"),
    ]));
  }
}

typedef UserPageArguments = ({
  int? id,
  E621AccessData? data,
  String? username,
  User? user
});

class UserProfilePageLoader extends StatefulWidget
    with IRoute<UserProfilePageLoader> {
  static lm.FileLogger get logger => UserProfilePage.logger;
  // #region Routing
  static const routeNameConst = UserProfilePage.routeNameConst,
      routeSegmentsConst = UserProfilePage.routeSegmentsConst,
      routePathConst = UserProfilePage.routePathConst,
      hasStaticPathConst = UserProfilePage.hasStaticPathConst;
  @override
  get routeName => routeNameConst;
  @override
  get hasStaticPath => hasStaticPathConst;
  @override
  get routeSegments => routeSegmentsConst;
  @override
  get routeSegmentsFolded => routePathConst;

  @override
  Widget generateWidgetForRoute(RouteSettings settings) =>
      generateWidgetForRouteStatic(settings);
  static Widget generateWidgetForRouteStatic(RouteSettings settings) =>
      UserProfilePage.generateWidgetForRouteStatic(settings);
  // #endregion Routing
  final User? user;
  final E621AccessData? data;
  final String? username;
  final int? id;

  const UserProfilePageLoader({
    super.key,
    this.user,
    this.id,
    this.data,
    this.username,
  }) : assert(
          (user ?? id ?? data ?? username) != null,
          "At least 1 of `user`, `id`, `data`, or `username` must be non-null",
        );
  const UserProfilePageLoader.byUser({
    super.key,
    required User this.user,
  })  : data = null,
        username = null,
        id = null;
  const UserProfilePageLoader.loadFromAccessData({
    super.key,
    required E621AccessData this.data,
  })  : username = null,
        id = null,
        user = null;
  const UserProfilePageLoader.getByName({
    super.key,
    required String this.username,
  })  : data = null,
        id = null,
        user = null;
  const UserProfilePageLoader.getById({
    super.key,
    required int this.id,
  })  : data = null,
        username = null,
        user = null;
  factory UserProfilePageLoader.fromRoute(RouteSettings settings) {
    if (settings.arguments != null) {
      switch (settings.arguments) {
        case UserPageArguments args:
          return UserProfilePageLoader(
            // data: args.data,
            id: args.id,
            user: args.user,
            username: args.username,
          );
        case User args:
          return UserProfilePageLoader(user: args);
        case int args:
          return UserProfilePageLoader(id: args);
        case E621AccessData args:
          return UserProfilePageLoader(data: args);
        case String args:
          return UserProfilePageLoader(username: args);
        case dynamic args:
          try {
            return UserProfilePageLoader(user: args.user!);
          } catch (_) {
            try {
              return UserProfilePageLoader(id: args.id!);
            } catch (_) {
              try {
                return UserProfilePageLoader(id: args.userId!);
              } catch (_) {
                try {
                  return UserProfilePageLoader(username: args.username!);
                } catch (_) {
                  try {
                    return UserProfilePageLoader(data: args.data!);
                  } catch (_) {
                    throw ArgumentError.value(
                        settings.arguments,
                        "settings.arguments",
                        "must have one of `int? id`, `E621AccessData? data`, `String? username`, `User? user`");
                  }
                }
              }
            }
          }
      }
    }
    final uri = Uri.parse(settings.name!);
    assert(routeNameConst.contains(uri.pathSegments.first));
    if (uri.pathSegments.length > 1) {
      return UserProfilePageLoader(id: int.parse(uri.pathSegments[1]));
    }
    final id = uri.queryParameters["id"] ??
        uri.queryParameters["user_id"] ??
        uri.queryParameters["userId"];
    final name = uri.queryParameters["name"] ??
        uri.queryParameters["user_name"] ??
        uri.queryParameters["username"];
    return UserProfilePageLoader(
      id: id != null ? int.tryParse(id) : null,
      username: name,
    );
  }

  @override
  State<UserProfilePageLoader> createState() => _UserProfilePageLoaderState();
}

class _UserProfilePageLoaderState extends State<UserProfilePageLoader> {
  FutureOr<User?>? userFuture;
  User? user;
  @override
  void initState() {
    void myThen(User? value) {
      if (value == null) {
        setState(() {
          user = userFuture = null;
        });
      } else {
        setState(() {
          user = value;
          userFuture = null;
        });
        E621.tryUpdateLoggedInUser(value);
      }
    }

    super.initState();
    userFuture = E621.retrieveUserMostSpecific(
      id: widget.id,
      user: widget.user,
      data: widget.data,
      username: widget.username,
    ); //widget.user;
    if (userFuture is User) {
      E621.tryUpdateLoggedInUser(user = userFuture as User);
      userFuture = null;
    } else if (userFuture.runtimeType == User) {
      user = userFuture as User;
      userFuture = E621.getUserDetailedFromId(user!.id)..then<void>(myThen);
    } else if (userFuture == null) {
      user = userFuture = null;
    } else if (userFuture is Future<UserLoggedInDetail?>) {
      (userFuture as Future<UserLoggedInDetail?>)
        ..then<void>(myThen)
        ..then((v) {
          if (v == null) {
            setState(() {
              user = userFuture = null;
            });
          } else {
            setState(() {
              user = v;
              userFuture = null;
            });
            E621.tryUpdateLoggedInUser(v);
          }
        });
    } else if (userFuture is Future<UserDetailed?>) {
      (userFuture as Future<UserDetailed?>)
        ..then<void>(myThen)
        ..then((v) {
          if (v == null) {
            setState(() {
              user = userFuture = null;
            });
          } else {
            setState(() {
              user = v;
              userFuture = null;
            });
          }
        });
    } else /* if (userFuture is Future<User?>) */ {
      (userFuture as Future<User?>)
        ..then<void>(myThen)
        ..then((v) {
          if (v == null) {
            setState(() {
              user = userFuture = null;
            });
          } else {
            setState(() {
              user = v;
              userFuture = null;
            });
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return user != null
        ? UserProfilePage(user: user!)
        : userFuture != null
            // ? scSaCoExArCpi
            ? Scaffold(
                appBar: AppBar(
                  title: const Text("User "),
                ),
                body:
                    spinnerFitted /* const Column(
                  children: [spinnerExpanded],
                ) */
                ,
              )
            : Scaffold(
                appBar: AppBar(title: const Text("Failed to load")),
                body: const Text("Failed to load"),
              );
  }
}
