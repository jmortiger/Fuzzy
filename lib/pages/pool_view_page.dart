import 'package:flutter/material.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:fuzzy/widgets/w_post_search_results.dart';

class PoolViewPage extends StatelessWidget {
  final PoolModel pool;
  const PoolViewPage({super.key, required this.pool});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: pool.posts.isAssigned
          ? WPostSearchResults(posts: E6PostsSync(posts: pool.posts.$))
          : FutureBuilder(
              future: pool.posts.getItem(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  try {
                    return WPostSearchResults(
                      posts: E6PostsSync(
                        posts: snapshot.data!,
                      ),
                      disallowSelections: true,
                    );
                  } catch (e, s) {
                    return Scaffold(
                      body: Text("$e\n$s\n${snapshot.data}\n${snapshot.stackTrace}"),
                    );
                  }
                } else if (snapshot.hasError) {
                  return Scaffold(
                    body: Text("${snapshot.error}\n${snapshot.stackTrace}"),
                  );
                } else {
                  return const Scaffold(
                    body: CircularProgressIndicator(),
                  );
                }
              },
            ),
    );
  }
}
