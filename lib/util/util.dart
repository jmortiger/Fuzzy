import 'package:fuzzy/web/models/e621/tag_d_b.dart';
import 'package:j_util/j_util_full.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path;

typedef JsonMap = Map<String, dynamic>;
final LazyInitializer<PackageInfo> packageInfo = LazyInitializer(
  () => PackageInfo.fromPlatform(),
);
final LazyInitializer<String> version = LazyInitializer(
  () async => (await packageInfo.getItem()).version,
  defaultValue: "VERSION_NUMBER",
);

final LazyInitializer<String> appDataPath =
    LazyInitializer(() => path.getApplicationDocumentsDirectory().then(
          (value) => value.absolute.path,
        ));

final Late<TagDB> tagDb = Late();
