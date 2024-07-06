import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:http/http.dart';
import 'package:j_util/e621.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart';

late final lRecord =
    lm.genLogger("UserProfilePage" /* , null, lm.LogLevel.FINEST */);
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

class UserProfilePage extends StatelessWidget {
  final User user;
  UserDetailed? get userD => user is UserDetailed ? user as UserDetailed : null;
  UserLoggedIn? get userL => user is UserLoggedIn ? user as UserLoggedIn : null;

  const UserProfilePage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "User ${user.id}: ${user.name}${user is UserLoggedIn ? " (You)" : ""}",
        ),
      ),
      body: Column(children: [
        // avatarId
        Text("Created At: ${user.createdAt}"),
        Text("Level: ${user.levelString}(${user.level})"),
        Text("Post Update Count: ${user.postUpdateCount}"),
        Text("Post Upload Count: ${user.postUploadCount}"),
        Text("Note Update Count: ${user.noteUpdateCount}"),
        Text("Is Banned: ${user.isBanned}"),
        Text("Can Approve Posts: ${user.canApprovePosts}"),
        Text("Can Upload Free: ${user.canUploadFree}"),
        Text("Base Upload Limit: ${user.baseUploadLimit}"),
        if (userL != null)
          Text("FavCount: ${userL!.favoriteCount}/${userL!.favoriteLimit}"),
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
    );
  }
}

class UserProfileLoaderPage extends StatefulWidget {
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
  FutureOr<User?> get user {
    if (_user != null) return _user;
    logger.finest("No User obj, trying access data");
    var d = (data ??
                E621AccessData.userData.itemSafe ??
                (isDebug ? E621AccessData.devAccessData.itemSafe : null))
            ?.cred,
        username = d?.username ?? this.username;
    if (d == null) {
      logger.finest("No access data, trying by name");
    }
    if (username == null || username.isEmpty) {
      logger.warning("No user info available: cannot find user");
      return null;
    }
    var r = Api.initSearchUsersRequest(
      searchNameMatches: d?.username,
      credentials: d,
      limit: 1,
    );
    logRequest(r, logger);
    return Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logResponse(v, logger, lm.LogLevel.SEVERE);
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logResponse(v, logger, lm.LogLevel.WARNING);
        return null;
      } else {
        logResponse(v, logger, lm.LogLevel.INFO);
        try {
          return UserLoggedIn.fromRawJson(v.body);
        } catch (e) {
          return User.fromRawJson(v.body);
        }
      }
    });
  }

  /// Based on the provided user info, attempts to get, in order:
  /// 1. [UserLoggedInDetail]
  /// 1. [UserDetailed]
  /// 1. [UserLoggedIn]
  /// 1. [User]
  FutureOr<User?> get userMostSpecific {
    var id = this.id;
    if (_user != null) {
      if (_user is UserLoggedInDetail || _user is UserDetailed) {
        return _user;
      } else {
        logger.finest("Attempting to retrieve more specific user "
            "info for user ${_user.id} (${_user.name})");
        id = _user.id;
      }
    } else {
      logger.finest("No User obj, trying id");
    }
    var d = (data ??
            E621AccessData.userData.itemSafe ??
            (isDebug ? E621AccessData.devAccessData.itemSafe : null))
        ?.cred;
    if (id != null) {
      if (d == null) {
        logger.info("No credential data, can't get logged in data.");
      }
      var r = Api.initGetUserRequest(
        id,
        credentials: d,
      );
      logRequest(r, logger);
      return Api.sendRequest(r).then(resolveGetUserFuture);
    }
    logger.finest("No id, trying access data");
    var username = d?.username ?? this.username;
    if (d == null) {
      logger.finest("No access data, trying by name");
    }
    if (username == null || username.isEmpty) {
      logger.warning("No user info available: cannot find user");
      return null;
    }
    var r = Api.initSearchUsersRequest(
      searchNameMatches: d?.username,
      credentials: d,
      limit: 1,
    );
    logRequest(r, logger);
    return Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logResponse(v, logger, lm.LogLevel.SEVERE);
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logResponse(v, logger, lm.LogLevel.WARNING);
        return null;
      } else {
        logResponse(v, logger, lm.LogLevel.FINER);
        User t;
        try {
          t = UserLoggedIn.fromRawJson(v.body);
        } catch (e) {
          t = User.fromRawJson(v.body);
        }
        logger.info("Launching request for User ${t.id} (${t.name})");
        var r = Api.initGetUserRequest(
          t.id,
          credentials: d,
        );
        logRequest(r, logger);
        return Api.sendRequest(r).then(resolveGetUserFuture);
      }
    });
  }

  static UserDetailed? resolveGetUserFuture(Response v) {
    if (v.statusCodeInfo.isError) {
      logResponse(v, logger, lm.LogLevel.SEVERE);
      return null;
    } else if (!v.statusCodeInfo.isSuccessful) {
      logResponse(v, logger, lm.LogLevel.WARNING);
      return null;
    } else {
      logResponse(v, logger, lm.LogLevel.FINER);
      try {
        return UserLoggedInDetail.fromRawJson(v.body);
      } catch (e) {
        return UserDetailed.fromRawJson(v.body);
      }
    }
  }

  static Future<UserDetailed?> getUserDetailedFromId(int id,
      [E6Credentials? c]) {
    var d = c ??
        (E621AccessData.userData.itemSafe ??
                (isDebug ? E621AccessData.devAccessData.itemSafe : null))
            ?.cred;
    if (d == null) {
      logger.finest("No access data");
    }
    var r = Api.initGetUserRequest(
      id,
      credentials: d,
    );
    logRequest(r, logger, lm.LogLevel.FINEST);
    return Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logResponse(v, logger, lm.LogLevel.SEVERE);
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logResponse(v, logger, lm.LogLevel.WARNING);
        return null;
      } else {
        logResponse(v, logger, lm.LogLevel.FINER);
        try {
          return UserLoggedInDetail.fromRawJson(v.body);
        } catch (e) {
          return UserDetailed.fromRawJson(v.body);
        }
      }
    });
  }

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
      }
    }

    super.initState();
    userFuture = widget.user;
    if (userFuture.runtimeType == UserDetailed) {
      user = userFuture as User;
      userFuture = null;
    } else if (userFuture.runtimeType == User) {
      user = userFuture as User;
      userFuture = UserProfileLoaderPage.getUserDetailedFromId(user!.id)
        ..then<void>(myThen);
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
                  children: [exArCpi],
                ),
              )
            : Scaffold(
                appBar: AppBar(),
                body: const Text("Failed"),
              );
  }
}
