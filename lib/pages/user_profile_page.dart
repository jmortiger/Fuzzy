import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:e621/e621.dart'
    show User, UserDetailed, UserLoggedIn, UserLoggedInDetail;

import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/widgets/w_post_thumbnail.dart';

import '../web/e621/e621_access_data.dart';

class UserProfilePage extends StatelessWidget
    implements IRoute<UserProfilePage> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("UserProfilePage");
  // #endregion Logger
  static const routeNameString = "/";
  @override
  get routeName => routeNameString;
  final User user;
  UserDetailed? get userD => user is UserDetailed ? user as UserDetailed : null;
  UserLoggedIn? get userL => user is UserLoggedIn ? user as UserLoggedIn : null;

  const UserProfilePage({
    super.key,
    required this.user,
  });
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
  static Widget generateFavStatsFull(UserLoggedIn userL, [int? deletedFavs]) =>
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
        child: Column(children: [
          if (user.avatarId != null) WPostThumbnail.withId(id: user.avatarId!),
          Text("Created At: ${user.createdAt}"),
          Text("Level: ${user.levelString}(${user.level})"),
          Text("Post Update Count: ${user.postUpdateCount}"),
          Text("Post Upload Count: ${user.postUploadCount}"),
          Text("Note Update Count: ${user.noteUpdateCount}"),
          Text("Is Banned: ${user.isBanned}"),
          Text("Can Approve Posts: ${user.canApprovePosts}"),
          Text("Can Upload Free: ${user.canUploadFree}"),
          Text("Base Upload Limit: ${user.baseUploadLimit}"),
          if (userL != null) generateFavStatsFull(userL!),
          if (userL != null) Text("Tag Query Limit: ${userL!.tagQueryLimit}"),
          if (userL != null) Text("Blacklist Users: ${userL!.blacklistUsers}"),
          if (userL != null) Text("Blacklisted Tags: ${userL!.blacklistedTags}"),
          if (userL != null) Text("Favorite Tags: ${userL!.favoriteTags}"),
          if (userL != null) Text("Api Burst Limit: ${userL!.apiBurstLimit}"),
          if (userL != null)
            Text("API Regen Multiplier: ${userL!.apiRegenMultiplier}"),
          if (userL != null)
            Text("Remaining API Limit: ${userL!.remainingApiLimit}"),
        ]),
      ),
    );
  }
}

class UserProfileLoaderPage extends StatefulWidget
    implements IRoute<UserProfileLoaderPage> {
  static lm.FileLogger get logger => UserProfilePage.logger;
  static const routeNameString = "/";
  @override
  get routeName => routeNameString;
  final User? _user;
  final E621AccessData? data;
  final String? username;
  final int? id;

  const UserProfileLoaderPage({
    super.key,
    required User user,
  })  : data = null,
        username = null,
        id = null,
        _user = user;
  const UserProfileLoaderPage.loadFromAccessData({
    super.key,
    required E621AccessData this.data,
  })  : username = null,
        id = null,
        _user = null;
  const UserProfileLoaderPage.getByName({
    super.key,
    required String this.username,
  })  : data = null,
        id = null,
        _user = null;
  const UserProfileLoaderPage.getById({
    super.key,
    required int this.id,
  })  : data = null,
        username = null,
        _user = null;
  // FutureOr<User?> get user {
  //   if (_user != null) return _user;
  //   logger.finest("No User obj, trying access data");
  //   var d = (data ??
  //               E621AccessData.userData.$Safe ??
  //               (isDebug ? E621AccessData.devAccessData.$Safe : null))
  //           ?.cred,
  //       username = this.username ?? d?.username;
  //   if (d == null) {
  //     logger.finest("No access data, trying by name");
  //   }
  //   if (username == null || username.isEmpty) {
  //     logger.warning("No user info available: cannot find user");
  //     return null;
  //   }
  //   var r = e621.initSearchUsersRequest(
  //     searchNameMatches: username,
  //     credentials: d,
  //     limit: 1,
  //   );
  //   logRequest(r, logger);
  //   return e621.sendRequest(r).then((v) {
  //     if (v.statusCodeInfo.isError) {
  //       logResponse(v, logger, lm.LogLevel.SEVERE);
  //       return null;
  //     } else if (!v.statusCodeInfo.isSuccessful) {
  //       logResponse(v, logger, lm.LogLevel.WARNING);
  //       return null;
  //     } else {
  //       logResponse(v, logger, lm.LogLevel.INFO);
  //       try {
  //         return UserLoggedIn.fromRawJson(v.body);
  //       } catch (e) {
  //         return User.fromRawJson(v.body);
  //       }
  //     }
  //   });
  // }

  // /// Based on the provided user info, attempts to get, in order:
  // /// 1. [UserLoggedInDetail]
  // /// 1. [UserDetailed]
  // /// 1. [UserLoggedIn]
  // /// 1. [User]
  // FutureOr<User?> get userMostSpecific {
  //   var id = this.id;
  //   if (_user != null) {
  //     if (_user is UserLoggedInDetail || _user is UserDetailed) {
  //       return _user;
  //     } else {
  //       logger.finest("Attempting to retrieve more specific user "
  //           "info for user ${_user.id} (${_user.name})");
  //       id = _user.id;
  //     }
  //   } else {
  //     logger.finest("No User obj, trying id");
  //   }
  //   var d = (data ??
  //           E621AccessData.userData.$Safe ??
  //           (isDebug ? E621AccessData.devAccessData.$Safe : null))
  //       ?.cred;
  //   if (id != null) {
  //     if (d == null) {
  //       logger.info("No credential data, can't get logged in data.");
  //     }
  //     var r = e621.initGetUserRequest(
  //       id,
  //       credentials: d,
  //     );
  //     logRequest(r, logger);
  //     return e621.sendRequest(r).then(E621.resolveGetUserFuture);
  //   }
  //   logger.finest("No id, trying access data");
  //   var username = this.username ?? d?.username;
  //   if (d == null) {
  //     logger.finest("No access data, trying by name");
  //   }
  //   if (username == null || username.isEmpty) {
  //     logger.warning("No user info available: cannot find user");
  //     return null;
  //   }
  //   var r = e621.initSearchUsersRequest(
  //     searchNameMatches: username,
  //     credentials: d,
  //     limit: 1,
  //   );
  //   logRequest(r, logger);
  //   return e621.sendRequest(r).then((v) {
  //     if (v.statusCodeInfo.isError) {
  //       logResponse(v, logger, lm.LogLevel.SEVERE);
  //       return null;
  //     } else if (!v.statusCodeInfo.isSuccessful) {
  //       logResponse(v, logger, lm.LogLevel.WARNING);
  //       return null;
  //     } else {
  //       logResponse(v, logger, lm.LogLevel.FINER);
  //       User t;
  //       try {
  //         t = UserLoggedIn.fromRawJson(v.body);
  //       } catch (e) {
  //         t = User.fromRawJson(v.body);
  //       }
  //       logger.info("Launching request for User ${t.id} (${t.name})");
  //       var r = e621.initGetUserRequest(
  //         t.id,
  //         credentials: d,
  //       );
  //       logRequest(r, logger);
  //       return e621.sendRequest(r).then(E621.resolveGetUserFuture);
  //     }
  //   });
  // }

  @override
  State<UserProfileLoaderPage> createState() => _UserProfileLoaderPageState();
}

class _UserProfileLoaderPageState extends State<UserProfileLoaderPage> {
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
    userFuture = E621.retrieveUserNonDetailed(
      user: widget._user,
      data: widget.data,
      username: widget.username,
    ); //widget.user;
    if (userFuture.runtimeType == UserDetailed) {
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
                body: const Column(
                  children: [spinnerExpanded],
                ),
              )
            : Scaffold(
                appBar: AppBar(),
                body: const Text("Failed"),
              );
  }
}
