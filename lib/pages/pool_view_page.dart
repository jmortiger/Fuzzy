import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dt;
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';

import 'package:j_util/e621.dart' as e621;
import 'package:j_util/j_util_full.dart';

class PoolViewPage extends StatefulWidget implements IRoute<PoolViewPage> {
  static const routeNameString = "/poolView";
  @override
  get routeName => routeNameString;
  final PoolModel pool;
  const PoolViewPage({super.key, required this.pool});

  @override
  State<PoolViewPage> createState() => _PoolViewPageState();
}

var forcePostUniqueness = true;

class _PoolViewPageState extends State<PoolViewPage> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("PoolViewPage").logger;
  PoolModel get pool => widget.pool;
  List<E6PostResponse> posts = [];
  Future<List<E6PostResponse>>? loadingPosts;
  int currentPage = 1;
  JPureEvent rebuild = JPureEvent();
  @override
  void initState() {
    super.initState();
    if (widget.pool.posts.isAssigned) {
      posts = widget.pool.posts.$;
    } else {
      loadingPosts = widget.pool.posts.getItemAsync()
        ..then((data) {
          logger.finest("Done loading");
          setState(() {
            if (posts.isNotEmpty) {
              posts.addAll(data);
              logger.finer(
                "posts.length before set conversion: ${posts.length}",
              );
              posts = posts.toSet().toList();
              logger.finer(
                "posts.length after set conversion: ${posts.length}",
              );
            } else {
              posts = data;
            }
            loadingPosts = null;
          });
        }).ignore();
    }
    currentPage = 1;
    rebuild = JPureEvent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Pool ${widget.pool.id}: ${widget.pool.namePretty} by ${pool.creatorName} (${pool.creatorId})"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.pool.description.isNotEmpty)
              ExpansionTile(
                title: const Text("Description"),
                dense: true,
                initiallyExpanded: true,
                children: [
                  SelectableText.rich(
                      dt.parse(widget.pool.description) as TextSpan)
                ],
              ),
            if (posts.isNotEmpty)
              Expanded(
                child: WPostSearchResults(
                  posts: E6PostsSync(posts: posts),
                  expectedCount: posts.length,
                  disallowSelections: true,
                  stripToGridView: true,
                  fireRebuild: rebuild,
                ),
              ),
            if (loadingPosts != null) spinnerExpanded,
            Center(
              child: Text(
                "Loaded ${posts.length}/${widget.pool.postCount} posts",
              ),
            ),
            if (widget.pool.postCount > posts.length && loadingPosts == null)
              TextButton(
                onPressed: () => setState(() {
                  loadingPosts = widget.pool.getPosts(page: ++currentPage)
                    ..then((data) {
                      logger.info("Done loading");
                      setState(() {
                        if (posts.isNotEmpty) {
                          posts.addAll(data);
                          if (forcePostUniqueness) {
                            logger.finer(
                              "posts.length before set conversion: ${posts.length}",
                            );
                            posts = posts.toSet().toList();
                            logger.finer(
                              "posts.length after set conversion: ${posts.length}",
                            );
                          }
                        } else {
                          posts = data;
                        }
                        loadingPosts = null;
                        rebuild.invoke();
                      });
                    });
                }),
                child: const Text("Load More"),
              ),
          ],
        ),
      ),
    );
  }
}

typedef PoolViewParameters = ({PoolModel? pool, int? id});

class PoolViewPageBuilder extends StatelessWidget
    implements IRoute<PoolViewPageBuilder> {
  static const routeNameString = "/pools";
  @override
  get routeName => routeNameString;
  final int poolId;

  const PoolViewPageBuilder({
    required this.poolId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: E621
          .sendRequest(e621.initGetPoolRequest(poolId))
          .toResponse()
          .then((v) => PoolViewPage(
                pool: PoolModel.fromRawJson(v.body),
              )),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          try {
            return snapshot.data!;
          } catch (e, s) {
            return Scaffold(
              appBar: AppBar(),
              body: Text(
                  "$e\n$s\n${snapshot.data}\n${snapshot.error}\n${snapshot.stackTrace}"),
            );
          }
        } else if (snapshot.hasError) {
          return ErrorPage(
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            logger: _PoolViewPageState.logger,
          );
        } else {
          return Scaffold(
            appBar: AppBar(title: Text("Pool $poolId")),
            body: const Column(children: [spinnerExpanded]),
          );
        }
      },
    );
  }
}
