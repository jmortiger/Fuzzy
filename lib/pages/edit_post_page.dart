import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/util/util.dart';
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util.dart';
import 'package:j_util/j_util_full.dart';

/// TODO: separate tags by category
/// TODO: Add children using `child:12345` https://e621.net/help/post_relationships
class EditPostPage extends StatefulWidget {
  final E6PostResponse post;
  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  // #region Logger
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("EditPostPage");
  // #endregion Logger
  E6PostResponse get post => widget.post;
  late List<String> editedTags;
  String? postTagStringDiff;
  String? postSourceDiff;
  String? postParentId;
  String? get postOldParentId => post.relationships.parentId?.toString();
  String? postDescription;
  String get postOldDescription => post.description;
  String? postRating;
  String? get postOldRating => post.rating;
  String? postIsRatingLocked;
  String? postIsNoteLocked;
  String? postEditReason;
  late TextEditingController controllerDescription;
  late TextEditingController controllerParentId;

  @override
  void initState() {
    super.initState();
    editedTags = post.tags.allTags;
    controllerDescription = TextEditingController(text: post.description);
    controllerParentId = post.relationships.parentId != null
        ? TextEditingController(text: post.relationships.parentId!.toString())
        : TextEditingController();
  }

  static String _folder(acc, e) => "$acc${acc.isEmpty ? "" : " "}$e";
  static String _minusFolder(acc, e) => "$acc${acc.isEmpty ? "" : " "}-$e";
  static const debugDeactivate = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SelectableText("${post.id}"),
      ),
      persistentFooterButtons: [
        IconButton(
          onPressed: () async {
            final origTags = post.tags.allTags.toSet();
            final editedTagSet = editedTags.toSet();
            final newTags = editedTagSet.difference(origTags).fold("", _folder);
            final removedTags =
                origTags.difference(editedTagSet).fold("", _minusFolder);
            final postTagStringDiff = _folder(newTags, removedTags);
            logger.info("postTagStringDiff: $postTagStringDiff");
            final req = e621.Api.initUpdatePostRequest(
              postId: post.id,
              postTagStringDiff: postTagStringDiff,
              postSourceDiff: postSourceDiff,
              postParentId: postParentId,
              postOldParentId: postOldParentId,
              postDescription: postDescription,
              postOldDescription: post.description,
              postRating: postRating,
              postOldRating: post.rating,
              postIsRatingLocked: postIsRatingLocked,
              postIsNoteLocked: postIsNoteLocked,
              postEditReason: postEditReason,
              credentials: E621AccessData.fallback?.cred,
            );
            logRequest(req, logger, lm.LogLevel.INFO);
            if (debugDeactivate) return;
            final res = await e621.Api.sendRequest(req);
            logResponse(res, logger, lm.LogLevel.INFO);
            Navigator.pop(
              context,
            );
          },
          icon: const Icon(Icons.check),
        ),
        IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.cancel_outlined),
        ),
      ],
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Edit Reason",
                  labelText: "Edit Reason",
                ),
                onChanged: (v) => postEditReason = v,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: controllerDescription,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Description",
                    labelText: "Description"),
                onChanged: (v) => postDescription = v,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: controllerParentId,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Parent Id",
                    labelText: "Parent Id"),
                onChanged: (v) => postParentId = v,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: WEnumField(
                name: "Rating",
                getVal: () =>
                    PostRating.getFromJsonResponse(postRating ?? post.rating),
                setVal: (Enum v) => postRating = (v as PostRating).name[0],
                values: PostRating.values,
              ),
            ),
            ExpansionTile(
              title: const Text("Tags"),
              initiallyExpanded: true,
              children: [
                ListTile(
                  title: const Text("Revert Changes"),
                  onTap: () => setState(() {
                    editedTags = post.tags.allTags;
                  }),
                ),
                ...editedTags.map(
                  (e) => WTagItem(
                    key: ObjectKey(e),
                    initialValue: e,
                    // onDuplicate: (initialValue, value) => ,
                    onRemove: (initialValue, value) => setState(() {
                      logger.info("Removing $initialValue (currently $value)");
                      final r = editedTags.remove(initialValue);
                      logger.info("Was successful: $r");
                    }),
                    onSubmitted: (initialValue, value) {
                      if (initialValue == value) {
                        logger.info("No change from $initialValue to $value");
                        return;
                      }
                      logger.info("Changing $initialValue to $value");
                      logger.info("start: $editedTags");
                      final temp = editedTags.toSet();
                      temp.remove(initialValue);
                      temp.add(value);
                      setState(() {
                        editedTags = temp.toList();
                      });
                      logger.info("end: $editedTags");
                    },
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WTagItem extends StatefulWidget {
  final String initialValue;
  final void Function(String initialValue, String value)? onRemove;
  final void Function(String initialValue, String value)? onDuplicate;
  final String? Function(String initialValue, String value)? onChange;
  final void Function(String initialValue, String value)? onSubmitted;
  const WTagItem({
    super.key,
    required this.initialValue,
    this.onRemove,
    this.onDuplicate,
    this.onChange,
    this.onSubmitted,
  });

  @override
  State<WTagItem> createState() => _WTagItemState();
}

/// TODO: Format input so only valid tag characters can be entered
class _WTagItemState extends State<WTagItem> {
  late String value;
  @override
  void initState() {
    super.initState();
    value = widget.initialValue;
  }

  // late bool isSelected
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onFocusChange: (value) {
        if (!value) {
          this.value.isEmpty
              ? widget.onRemove?.call(widget.initialValue, this.value)
              : widget.onSubmitted?.call(widget.initialValue, this.value);
        }
      },
      title: TextField(
        inputFormatters: [
          TextInputFormatter.withFunction(
            (oldValue, newValue) =>
                newValue.text.contains(RegExp(RegExpExt.whitespacePattern))
                    ? oldValue
                    : newValue,
          )
        ],
        controller: TextEditingController(
          text: widget.initialValue,
        ),
        onChanged: (value) => this.value =
            widget.onChange?.call(widget.initialValue, value) ?? value,
        onTapOutside: (event) => value.isEmpty
            ? widget.onRemove?.call(widget.initialValue, value)
            : widget.onSubmitted?.call(widget.initialValue, value),
        onSubmitted: (value) =>
            widget.onSubmitted?.call(widget.initialValue, value),
      ),
      trailing: widget.onDuplicate != null
          ? IconButton(
              onPressed: () =>
                  widget.onRemove?.call(widget.initialValue, value),
              icon: const Icon(Icons.remove),
            )
          : null,
      leading: widget.onDuplicate != null
          ? IconButton(
              onPressed: () =>
                  widget.onDuplicate?.call(widget.initialValue, value),
              icon: const Icon(Icons.remove),
            )
          : null,
    );
  }
}

class EditPostPageLoader extends StatelessWidget
    implements IRoute<EditPostPageLoader> {
  static const routeNameString = "/post/edit";
  @override
  String get routeName => routeNameString;
  final int? postId;
  final E6PostResponse? post;

  const EditPostPageLoader({
    super.key,
    required int this.postId,
  }) : post = null;
  const EditPostPageLoader.loaded({
    super.key,
    required E6PostResponse this.post,
    // this.postId,
  }) : postId = null;

  @override
  Widget build(BuildContext context) {
    return post != null
        ? EditPostPage(post: post!)
        : FutureBuilder(
            future: e621.Api.sendRequest(e621.Api.initSearchPostRequest(
              postId!,
              credentials: E621.accessData.$Safe?.cred,
            )),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return EditPostPage(
                    post: E6PostResponse.fromRawJson(snapshot.data!.body));
              } else if (snapshot.hasError) {
                return ErrorPage(
                  error: snapshot.error,
                  stackTrace: snapshot.stackTrace,
                );
              } else {
                return fullPageSpinner;
              }
            },
          );
  }
}
