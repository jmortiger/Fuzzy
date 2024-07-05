import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:j_util/e621.dart';

// #region Logger
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart';

late final lRecord = lm.genLogger("UserProfilePage");
late final print = lRecord.print;
late final logger = lRecord.logger;
// #endregion Logger

class UserProfilePage extends StatelessWidget {
  final User user;
  UserDetailed? get userD => user is UserDetailed ? user as UserDetailed : null;
  UserLoggedIn? get userL =>
      user is UserLoggedIn ? user as UserLoggedIn : null;

  const UserProfilePage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User ${user.id}: ${user.name}"),
      ),
      body: Column(children: [
        if (userL != null)
          Text("FavCount: ${userL!.favoriteCount}/${userL!.favoriteLimit}"),
      ]),
    );
  }
}

class UserProfileLoaderPage extends StatefulWidget {
  final User? _user;
  final E621AccessData? data;
  final String? username;

  const UserProfileLoaderPage({
    super.key,
    required User user,
  })  : data = null,
        username = null,
        _user = user;
  const UserProfileLoaderPage.loadFromAccessData({
    super.key,
    required E621AccessData this.data,
  })  : username = null,
        _user = null;
  const UserProfileLoaderPage.getByName({
    super.key,
    required String this.username,
  })  : data = null,
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
      // searchOrder: UserOrder.name,
      credentials: d,
      limit: 1,
    );
    logger.finest(
      "Request:"
      "\n\t$r"
      "\n\t${r.url}"
      "\n\t${r.url.query}"
      "\n\t${r.body}"
      "\n\t${r.headers}",
    );
    return Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logger.severe(
          "Response:"
          "\n\t$v"
          "\n\t${v.body}"
          "\n\t${v.statusCode}"
          "\n\t${v.headers}",
        );
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logger.warning(
          "Response:"
          "\n\t$v"
          "\n\t${v.body}"
          "\n\t${v.statusCode}"
          "\n\t${v.headers}",
        );
        return null;
      } else {
        logger.info(
          "Response:"
          "\n\t$v"
          "\n\t${v.body}"
          "\n\t${v.statusCode}"
          "\n\t${v.headers}",
        );
        return User.fromRawJson(v.body);
      }
    });
  }

  static Future<UserDetailed?> getUserDetailedFromId(int id,
      [E6Credentials? c]) {
    logger.finest("No User obj, trying access data");
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
    logger.finest(
      "Request:"
      "\n\t$r"
      "\n\t${r.url}"
      "\n\t${r.url.query}"
      "\n\t${r.body}"
      "\n\t${r.headers}",
    );
    return Api.sendRequest(r).then((v) {
      if (v.statusCodeInfo.isError) {
        logger.severe(
          "Response:"
          "\n\t$v"
          "\n\t${v.body}"
          "\n\t${v.statusCode}"
          "\n\t${v.headers}",
        );
        return null;
      } else if (!v.statusCodeInfo.isSuccessful) {
        logger.warning(
          "Response:"
          "\n\t$v"
          "\n\t${v.body}"
          "\n\t${v.statusCode}"
          "\n\t${v.headers}",
        );
        return null;
      } else {
        logger.info(
          "Response:"
          "\n\t$v"
          "\n\t${v.body}"
          "\n\t${v.statusCode}"
          "\n\t${v.headers}",
        );
        return UserDetailed.fromRawJson(v.body);
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
    } else if (userFuture.runtimeType == Future<User?>) {
      (userFuture as Future<User?>).then<void>(myThen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return user != null
        ? UserProfilePage(user: user!)
        : userFuture != null
            ? scSaCoExArCpi
            : Scaffold(
                appBar: AppBar(),
                body: const Text("Failed"),
              );
  }
}
