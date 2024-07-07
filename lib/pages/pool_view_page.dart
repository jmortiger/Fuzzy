import 'package:flutter/material.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';

import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/e621.dart';
import 'package:j_util/j_util_full.dart';

late final lRecord = lm.genLogger("pool_view_page.dart");
lm.Printer get print => lRecord.print;
lm.FileLogger get logger => lRecord.logger;

class PoolViewPage extends StatefulWidget implements IRoute<PoolViewPage> {
  // #region Logger
  static late final lRecord = lm.genLogger("PoolViewPage");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
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
  // #region Logger
  static late final lRecord = lm.genLogger("_PoolViewPageState");
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // #endregion Logger
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
      loadingPosts = widget.pool.posts.getItem()
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
        });
    }
    currentPage = 1;
    rebuild = JPureEvent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pool ${widget.pool.id}: ${widget.pool.namePretty} by ${pool.creatorName} (${pool.creatorId})"),
      ),
      body: SafeArea(
        child: //posts.isNotEmpty ?
            Column(
          // mainAxisSize: MainAxisSize.min,
          children: [
            ExpansionTile(
              title: const Text("Description"),
              dense: true,
              initiallyExpanded: true,
              children: [SelectableText(widget.pool.description)],
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
            if (loadingPosts != null)
              exArCpi,
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
        // : const Center(
        //     child: AspectRatio(
        //       aspectRatio: 1,
        //       child: CircularProgressIndicator(),
        //     ),
        //   ),
      ),
    );
  }
}
class PoolViewPageBuilder extends StatelessWidget
    implements IRoute<PoolViewPageBuilder> {
  static const routeNameString = "/pool";
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
          .sendRequest(
              // Api.initSearchPoolsRequest(searchId: [poolId]))
              Api.initGetPoolRequest(poolId))
          .toResponse()
          // .then((v) => jsonDecode(v.body))
          .then((v) => PoolViewPage(
                // pool: PoolModel.fromJson(v[0]),
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
          return Scaffold(
            appBar: AppBar(),
            body: Text("${snapshot.error}\n${snapshot.stackTrace}"),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: Text("Pool $poolId"),
            ),
            body: const Column(
              children: [
                exArCpi,
              ],
            ),
          );
        }
      },
    );
  }
}