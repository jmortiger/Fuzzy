import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/models/cached_favorites.dart';
import 'package:fuzzy/models/saved_data.dart';

enum MyFile {
  settings(AppSettings.fileName),
  cachedFavorites(CachedFavorites.fileName),
  savedSearches(SavedDataE6Legacy.fileName),
  ;

  final String fileName;
  const MyFile(this.fileName);
  // String getFilePath(MyFile file) => switch (file) {
  //       settings => "settings.json",
  //       cachedFavorites => throw UnimplementedError(),
  //   savedSearches => throw UnimplementedError(),
  //     };
}
