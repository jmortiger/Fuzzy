import 'package:flutter/material.dart';
import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/selected_posts.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/util/util.dart' as util show defaultOnLinkifyOpen;
// import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/web/e621/post_collection.dart';
import 'package:fuzzy/widgets/w_image_result.dart' as w;
// import 'package:j_util/j_util_full.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';

import 'package:fuzzy/log_management.dart' as lm;

class PostGrid extends StatelessWidget {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("PostGrid").logger;

  final int pageIndex;
  final int indexOffset;
  final E6PostsSync posts;

  final bool useLazyBuilding;

  final bool disallowSelections;

  final bool stripToGridView;

  final bool useProviderForPosts;

  final bool filterBlacklist;

  const PostGrid({
    super.key,
    required this.posts,
    this.pageIndex = 0,
    this.indexOffset = 0,
    this.useLazyBuilding = false,
    required this.disallowSelections,
    this.stripToGridView = false,
    required this.filterBlacklist,
    required this.useProviderForPosts,
  });

  int get trueCount => posts.tryGetAll(filterBlacklist: filterBlacklist).length;

  @override
  Widget build(BuildContext context) {
    // final sc = useProviderForPosts //!stripToGridView
    //     ? Provider.of<ManagedPostCollectionSync>(context, listen: false)
    //     : null;
    final root = useLazyBuilding
        ? GridView.builder(
            gridDelegate: SearchView.gridDelegate,
            itemCount: trueCount,
            itemBuilder: (ctx, i) {
              final data = posts.tryGet(i, filterBlacklist: filterBlacklist);
              return (data == null) ? null : constructImageResult(data, i, ctx);
            },
          )
        : GridView.count(
            crossAxisCount: SearchView.i.postsPerRow,
            crossAxisSpacing: SearchView.i.horizontalGridSpace,
            mainAxisSpacing: SearchView.i.verticalGridSpace,
            childAspectRatio: SearchView.i.widthToHeightRatio,
            children: (() {
              final usedPosts = <E6PostResponse>{}, acc = <Widget>[];
              for (var i = 0,
                      p = posts.tryGet(i, filterBlacklist: filterBlacklist);
                  i < trueCount && p != null;
                  ++i, p = posts.tryGet(i, filterBlacklist: filterBlacklist)) {
                if (usedPosts.add(p)) {
                  acc.add(constructImageResult(p, i, context));
                }
              }
              return acc;
            })(),
          );
    // : useProviderForPosts //!stripToGridView
    //     ? Selector<ManagedPostCollectionSync, Iterable<E6PostResponse>?>(
    //         selector: (context, v) =>
    //             v.getPostsOnPageSync(pageIndex, filterBlacklist),
    //         builder: (_, v, __) => GridView.count(
    //           crossAxisCount: SearchView.i.postsPerRow,
    //           crossAxisSpacing: SearchView.i.horizontalGridSpace,
    //           mainAxisSpacing: SearchView.i.verticalGridSpace,
    //           childAspectRatio: SearchView.i.widthToHeightRatio,
    //           children: sc!
    //                   .getPostsOnPageSync(pageIndex, filterBlacklist)
    //                   ?.mapTo((e, i, _) => constructImageResult(
    //                         e,
    //                         i + sc.getPageFirstPostIndex(pageIndex),
    //                       ))
    //                   .toList() ??
    //               [],
    //         ),
    //       )
    //     : GridView.count(
    //         crossAxisCount: SearchView.i.postsPerRow,
    //         crossAxisSpacing: SearchView.i.horizontalGridSpace,
    //         mainAxisSpacing: SearchView.i.verticalGridSpace,
    //         childAspectRatio: SearchView.i.widthToHeightRatio,
    //         children: (() {
    //           final usedPosts = <E6PostResponse>{}, acc = <Widget>[];
    //           for (var i = 0,
    //                   p = posts.tryGet(i, filterBlacklist: filterBlacklist);
    //               i < trueCount && p != null;
    //               ++i,
    //               p = posts.tryGet(i, filterBlacklist: filterBlacklist)) {
    //             if (usedPosts.add(p)) acc.add(constructImageResult(p, i));
    //           }
    //           return acc;
    //         })(),
    //       );
    return !stripToGridView && posts.restrictedIndices.isNotEmpty
        ? Column(
            children: [
              Linkify(
                onOpen: util.defaultOnLinkifyOpen,
                text: "${posts.restrictedIndices.length} "
                    "hidden by global blacklist. "
                    "https://e621.net/help/global_blacklist",
                linkStyle: const TextStyle(color: Colors.yellow),
              ),
              Expanded(child: root),
            ],
          )
        : root;
  }

  @widgetFactory
  Widget constructImageResult(
          E6PostResponse data, int index, BuildContext context) =>
      ErrorPage.errorWidgetWrapper(
        () => !disallowSelections
            ? Selector<SelectedPosts, bool>(
                builder: (_, value, __) => w.ImageResult(
                  disallowSelections: disallowSelections,
                  imageListing: data,
                  index: useProviderForPosts
                      ? Provider.of<ManagedPostCollectionSync>(context,
                                  listen: false)
                              .getPageFirstPostIndex(pageIndex) +
                          index
                      : index,
                  filterBlacklist: filterBlacklist,
                  postsCache: !useProviderForPosts ? posts.posts : null,
                  isSelected: value,
                ),
                selector: (_, v) => v.getIsPostSelected(data.id),
              )
            : w.ImageResult(
                disallowSelections: disallowSelections,
                imageListing: data,
                index: useProviderForPosts
                    ? Provider.of<ManagedPostCollectionSync>(context,
                                listen: false)
                            .getPageFirstPostIndex(pageIndex) +
                        index
                    : index,
                filterBlacklist: filterBlacklist,
                postsCache: !useProviderForPosts ? posts.posts : null,
                isSelected: false,
              ),
        logger: logger,
      ).value;
}
