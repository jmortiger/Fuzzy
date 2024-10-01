import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/i_route.dart';
import 'package:fuzzy/pages/error_page.dart';
import 'package:fuzzy/pages/settings_page.dart';
import 'package:fuzzy/util/string_comparator.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/util/tag_db_import.dart' as tag_d_b;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:fuzzy/web/e621/models/e6_models.dart';
import 'package:e621/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/widgets/w_post_thumbnail.dart';
import 'package:j_util/j_util_full.dart';

const bool useAdvancedEditor = false;

/// TODO: separate tags by category
/// TODO: improve Performance
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
  static late final lRecord = lm.generateLogger("EditPostPage");
  // #endregion Logger
  E6PostResponse get post => widget.post;
  late List<String> editedTags;
  late List<String> editedSources;
  late String editedTagsString;
  late String editedSourcesString;
  late SearchController editedTagsStringController;
  late SearchController editedSourcesStringController;
  String? get postTagStringDiff {
    final origTags = post.tags.allTags.toSet();
    final editedTagSet = useAdvancedEditor
        ? editedTags.toSet()
        : editedTagsString.split(RegExp(r"\s")).toSet();
    final newTags = editedTagSet.difference(origTags).fold("", _folder);
    final removedTags =
        origTags.difference(editedTagSet).fold("", _minusFolder);
    final combined = _folder(newTags, removedTags);
    return combined.isEmpty ? null : combined;
  }

  // String? get postTagStringDiff => _postTagStringDiff;
  // set postTagStringDiff(String? v) =>
  //     _postTagStringDiff = v?.isEmpty ?? true ? null : v;
  String? get postSourceDiff {
    final origSources = post.sources.toSet();
    final editedSourcesSet = useAdvancedEditor
        ? editedSources.toSet()
        : editedSourcesString.split(RegExp(r"\s")).toSet();
    final newSources =
        editedSourcesSet.difference(origSources).fold("", _folder);
    final removedSources =
        origSources.difference(editedSourcesSet).fold("", _minusFolder);
    final combined = _folder(newSources, removedSources);
    return combined.isEmpty ? null : combined;
  }

  // String? get postSourceDiff => _postSourceDiff;
  // set postSourceDiff(String? v) =>
  //     _postSourceDiff = v?.isEmpty ?? true ? null : v;
  int? postParentId;
  // int? get postParentId => _postParentId;
  // set postParentId(int? v) => _postParentId = v == postOldParentId ? -1 : v;
  String? postDescription;
  String? postRating;
  int? get postOldParentId => post.relationships.parentId;
  String get postOldDescription => post.description;
  String? get postOldRating => post.rating;
  bool? postIsRatingLocked;
  bool? postIsNoteLocked;
  String? postEditReason;
  late TextEditingController controllerDescription;
  late TextEditingController controllerParentId;

  @override
  void initState() {
    super.initState();
    postParentId = postOldParentId;
    postDescription = postOldDescription;
    postRating = postOldRating;
    if (useAdvancedEditor) {
      editedTags = post.tags.allTags;
      editedSources = post.sources;
    } else {
      editedTagsString =
          post.tags.allTags.fold("", (p, e) => p.isEmpty ? e : "$p\n$e");
      editedSourcesString =
          post.sources.fold("", (p, e) => p.isEmpty ? e : "$p\n$e");
      editedTagsStringController = SearchController()
          /* ..addListener(() => setState(() {
              editedTagsString = editedTagsStringController.text;
            })) */
          ;
      editedSourcesStringController = SearchController()
          /* ..addListener(() => setState(() {
              editedSourcesString = editedSourcesStringController.text;
            })) */
          ;
    }
    controllerDescription = TextEditingController(text: post.description);
    controllerParentId = post.relationships.parentId != null
        ? TextEditingController(text: post.relationships.parentId!.toString())
        : TextEditingController();
  }

  @override
  void dispose() {
    if (!useAdvancedEditor) {
      editedTagsStringController.dispose();
      editedSourcesStringController.dispose();
    }
    controllerDescription.dispose();
    controllerParentId.dispose();
    super.dispose();
  }

  void validate() {
    if (useAdvancedEditor) {
      setState(() {
        editedTags = editedTags.toSet().toList();
        editedSources = editedSources.toSet().toList();
      });
    } else {
      setState(() {
        editedTagsString = editedTagsString
            .split(RegExp(r"\s"))
            .toSet()
            .fold("", (p, e) => p.isEmpty ? e : "$p\n$e");
        editedSourcesString = editedSourcesString
            .split(RegExp(r"\s"))
            .toSet()
            .fold("", (p, e) => p.isEmpty ? e : "$p\n$e");
      });
    }
  }

  static String _folder(acc, e) => "$acc${acc.isEmpty ? "" : " "}$e";
  static String _minusFolder(acc, e) => "$acc${acc.isEmpty ? "" : " "}-$e";
  static const debugDeactivate = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SelectableText("${post.id}"),
      ),
      persistentFooterButtons: [
        IconButton(
          onPressed: () async {
            validate();
            logger.info("postTagStringDiff: $postTagStringDiff");
            // if ((postTagStringDiff ??
            //             postDescription ??
            //             postRating ??
            //             postSourceDiff) !=
            //         null ||
            //     postParentId != postOldParentId) {
            if (e621.doesPostEditHaveChanges(
              postTagStringDiff: postTagStringDiff,
              postSourceDiff: postSourceDiff,
              postParentId: postParentId,
              postOldParentId: postOldParentId,
              postDescription: postDescription,
              postOldDescription: post.description,
              postRating: postRating,
              postOldRating: post.rating,
            )) {
              final req = e621.initPostEdit(
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
              lm.logRequest(req, logger, lm.LogLevel.INFO);
              if (debugDeactivate) return;
              final res = await e621.sendRequest(req).catchError(
                (error, stackTrace) {
                  logger.severe(
                      "Failed to edit post ${post.id}", error, stackTrace);
                  return error;
                },
              );
              lm.logResponseSmart(res, logger, baseLevel: lm.LogLevel.INFO);
              if (mounted) {
                Navigator.pop(this.context);
              }
            } else {
              logger.info("No changes detected");
              final req = e621.initPostEdit(
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
              lm.logRequest(req, logger, lm.LogLevel.INFO);
            }
          },
          icon: const Icon(Icons.check_circle_outline),
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
            WPostThumbnail.withPost(
              post: widget.post,
              maxWidth: MediaQuery.sizeOf(context).width,
              // fit: BoxFit.fitWidth,
            ),
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
                inputFormatters: [util.numericFormatter],
                controller: controllerParentId,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Parent Id",
                    labelText: "Parent Id"),
                onChanged: (v) =>
                    postParentId = v.isEmpty ? null : int.tryParse(v),
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
              initiallyExpanded: false,
              children: useAdvancedEditor
                  ? ([
                      ListTile(
                        title: const Text("Revert Changes"),
                        onTap: () => setState(() {
                          editedTags = post.tags.allTags;
                        }),
                      ),
                      ListTile(
                        title: const Text("Add tag"),
                        // onTap: () => editedTags.insert(0, ""),
                        onTap: () => setState(() {
                          editedTags.insert(0, "");
                        }),
                      ),
                      ...editedTags.mapAsList(tagMapper),
                    ])
                  : [
                      // TextField(
                      //   controller: TextEditingController(
                      //     text: editedTagsString,
                      //   ),
                      //   onChanged: (value) => setState(() {
                      //     editedTagsString = value;
                      //   }),
                      // )
                      Text(editedTagsString),
                      SearchAnchor(
                        // builder: (context, controller) => TextButton(
                        //   onPressed: () => controller.openView(),
                        //   child: const Text("Edit"),
                        // ),
                        builder: (context, controller) =>
                            SearchBar(onTap: controller.openView),
                        searchController: editedTagsStringController,
                        viewTrailing: [
                          SelectorNotifier(
                              selector: (context, value) => value.text,
                              builder: (context, value, child) =>
                                  editedTagsString.contains(
                                          RegExp(r"(^|\s)" "$value" r"(\s|$)"))
                                      ? IconButton(
                                          onPressed: () => setState(() {
                                            editedTagsString =
                                                editedTagsString.replaceFirst(
                                                    RegExp(r"(^|\s)"
                                                        "$value"
                                                        r"(\s|$)"),
                                                    "\n");
                                            editedTagsStringController.text =
                                                "";
                                          }),
                                          icon: const Icon(Icons.remove),
                                        )
                                      : IconButton(
                                          onPressed: () => setState(() {
                                            editedTagsString += "\n$value";
                                            editedTagsStringController.text =
                                                "";
                                          }),
                                          icon: const Icon(Icons.add),
                                        ),
                              value: editedTagsStringController)
                        ],
                        suggestionsBuilder: (context, controller) {
                          final c = getFineInverseSimilarityComparator(
                              controller.text);
                          return (tag_d_b.tagDbLazy.$Safe
                                  ?.getSublist(controller.text,
                                      allowedVariance: .6)
                                  .take(50)
                                  .map((e) => ListTile(
                                        title: Text(e.name),
                                        subtitle: Text(e.category.name),
                                        onTap: () => controller.text = e.name,
                                      ))
                                  .toList()
                                ?..sort((a, b) => c((a.title as Text).data!,
                                    (b.title as Text).data!))) ??
                              const Iterable<ListTile>.empty();
                        },
                      )
                    ],
            ),
            ExpansionTile(
              title: const Text("Sources"),
              initiallyExpanded: false,
              children: useAdvancedEditor
                  ? ([
                      ListTile(
                        title: const Text("Revert Changes"),
                        onTap: () => setState(() {
                          editedSources = post.sources;
                        }),
                      ),
                      ListTile(
                        title: const Text("Add Source"),
                        // onTap: () => editedSources.insert(0, ""),
                        onTap: () => setState(() {
                          editedSources.insert(0, "");
                        }),
                      ),
                      ...editedSources.mapAsList(sourceMapper),
                    ])
                  : [
                      // TextField(
                      //   controller: TextEditingController(
                      //     text: editedSourcesString,
                      //   ),
                      //   onChanged: (value) => setState(() {
                      //     editedSourcesString = value;
                      //   }),
                      // )
                      Text(editedSourcesString),
                      SearchAnchor(
                        builder: (context, controller) =>
                            SearchBar(onTap: controller.openView),
                        searchController: editedSourcesStringController,
                        viewTrailing: [
                          SelectorNotifier(
                              selector: (context, value) => value.text,
                              builder: (context, value, child) =>
                                  editedSourcesString.contains(
                                          RegExp(r"(^|\s)" "$value" r"(\s|$)"))
                                      ? IconButton(
                                          onPressed: () => setState(() {
                                            editedSourcesString =
                                                editedSourcesString
                                                    .replaceFirst(
                                                        RegExp(r"(^|\s)"
                                                            "$value"
                                                            r"(\s|$)"),
                                                        "\n");
                                            editedSourcesStringController.text =
                                                "";
                                          }),
                                          icon: const Icon(Icons.remove),
                                        )
                                      : IconButton(
                                          onPressed: () => setState(() {
                                            editedSourcesString += "\n$value";
                                            editedSourcesStringController.text =
                                                "";
                                          }),
                                          icon: const Icon(Icons.add),
                                        ),
                              value: editedSourcesStringController)
                        ],
                        suggestionsBuilder: (context, controller) {
                          final c = getFineInverseSimilarityComparator(
                              controller.text);
                          return (editedSourcesString.split(RegExp("\\s"))
                                ..sort(c))
                              .take(50)
                              .map((e) => ListTile(
                                    title: Text(e),
                                    onTap: () => controller.text = e,
                                  ));
                        },
                      )
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget tagMapper(String tag, [int i = 0, Iterable<String> l = const []]) {
    // final ctr = TextEditingController(text: tag);
    // ctr.addListener(() => tag ctr.value.text)
    return WTagItem(
      // controller: ctr..addListener(() => ),
      // key: ObjectKey(tag),
      key: ObjectKey("$tag$i"),
      initialValue: tag,
      // onRemove: (initialValue, value) {
      //   logger.info("Removing $initialValue (currently $value)");
      //   final r = editedTags.remove(initialValue);
      //   logger.info("Was successful: $r");
      // },
      onRemove: (initialValue, value) => setState(() {
        logger.info("Removing $initialValue (currently $value)");
        final r = editedTags.remove(initialValue);
        logger.info("Was successful: $r");
      }),
      // onChange: (initialValue, value) => editedTags[editedTags.indexOf(initialValue)] = value,
      onSubmitted: (initialValue, value) {
        if (initialValue == value) {
          logger.info("No change from $initialValue to $value");
          return null;
        }
        // if (editedTags.contains(value)) {
        //   logger.info("Tag $value already in tags at index ${editedTags.indexOf(value)}");
        //   return null;
        // }
        logger.info("Changing $initialValue to $value");
        logger.finest("start: $editedTags");
        final ind = editedTags.indexOf(initialValue);
        if (ind < 0) {
          logger.info(
              "Initial value $initialValue not found in collection, can't replace with $value");
          return false;
        }
        setState(() {
          editedTags[ind] = value;
        });
        // final temp = editedTags.toSet();
        // temp.remove(initialValue);
        // temp.add(value);
        // setState(() {
        //   editedTags = temp.toList();
        // });
        logger.finest("end: $editedTags");
        return true;
      },
      onDuplicate: (initialValue, value) {
        var i = editedTags.indexOf(initialValue);
        if (i >= 0) {
          setState(() {
            editedTags.insert(i, "$value*");
          });
        } else {
          setState(() {
            editedTags.add("$value*");
          });
        }
      },
    );
  }

  Widget sourceMapper(String source,
      [int i = 0, Iterable<String> l = const []]) {
    // final ctr = TextEditingController(text: source);
    // ctr.addListener(() => source ctr.value.text)
    return WTagItem(
      // controller: ctr..addListener(() => ),
      // key: ObjectKey(source),
      key: ObjectKey("$source$i"),
      initialValue: source,
      // onRemove: (initialValue, value) {
      //   logger.info("Removing $initialValue (currently $value)");
      //   final r = editedSources.remove(initialValue);
      //   logger.info("Was successful: $r");
      // },
      onRemove: (initialValue, value) => setState(() {
        logger.info("Removing $initialValue (currently $value)");
        final r = editedSources.remove(initialValue);
        logger.info("Was successful: $r");
      }),
      // onChange: (initialValue, value) => editedSources[editedSources.indexOf(initialValue)] = value,
      onSubmitted: (initialValue, value) {
        if (initialValue == value) {
          logger.info("No change from $initialValue to $value");
          return null;
        }
        logger.info("Changing $initialValue to $value");
        logger.finest("start: $editedSources");
        final ind = editedSources.indexOf(initialValue);
        if (ind < 0) {
          logger.info(
              "Initial value $initialValue not found in collection, can't replace with $value");
          return false;
        }
        setState(() {
          editedSources[ind] = value;
        });
        // final temp = editedSources.toSet();
        // temp.remove(initialValue);
        // temp.add(value);
        // setState(() {
        //   editedSources = temp.toList();
        // });
        logger.finest("end: $editedSources");
        return true;
      },
      onDuplicate: (initialValue, value) {
        var i = editedSources.indexOf(initialValue);
        if (i >= 0) {
          setState(() {
            editedSources.insert(i, "$value*");
          });
        } else {
          setState(() {
            editedSources.add("$value*");
          });
        }
      },
    );
  }
}

// class WListUniqueStringEditor extends StatelessWidget {
//   final List<String> list;
//   final String name;
//   final List<String> Function(List<String>)? onCollectionChanged;
//   final List<String> Function(List<String>)? onRevertChanges;
//   const WListUniqueStringEditor({
//     super.key,
//     required this.list,
//     required this.name,
//     this.onCollectionChanged,
//     this.onRevertChanges,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ExpansionTile(
//       title: const Text("Tags"),
//       initiallyExpanded: false,
//       children: [
//         ListTile(
//           title: const Text("Revert Changes"),
//           onTap: () => setState(() {
//             editedTags = post.tags.allTags;
//           }),
//         ),
//         ListTile(
//           title: const Text("Add tag"),
//           // onTap: () => editedTags.insert(0, ""),
//           onTap: () => setState(() {
//             editedTags.insert(0, "");
//           }),
//         ),
//         ...editedTags.mapAsList(tagMapper),
//       ],
//     );
//   }
// }

// class WTagItem extends StatelessWidget {
//   final String initialValue;
//   final void Function(String initialValue, String value)? onRemove;
//   final void Function(String initialValue, String value)? onDuplicate;
//   final String? Function(String initialValue, String value)? onChange;
//   // final String? Function(String initialValue, String priorValue, String newValue)? onChange;
//   final void Function(String initialValue, String value)? onSubmitted;
//   final TextEditingController? controller;
//   const WTagItem({
//     super.key,
//     required this.initialValue,
//     this.onRemove,
//     this.onDuplicate,
//     this.onChange,
//     this.onSubmitted,
//     this.controller,
//   });

//   // late bool isSelected
//   @override
//   Widget build(BuildContext context) {
//     String _value = initialValue;
//     return ListTile(
//       // onFocusChange: (value) {
//       //   if (!value) {
//       //     this.value.isEmpty
//       //         ? widget.onRemove?.call(widget.initialValue, this.value)
//       //         : widget.onSubmitted?.call(widget.initialValue, this.value);
//       //   }
//       // },
//       title: TextField(
//         inputFormatters: [
//           TextInputFormatter.withFunction(
//             (oldValue, newValue) =>
//                 newValue.text.contains(RegExp(r"\s"))
//                     ? oldValue
//                     : newValue,
//           )
//         ],
//         controller: controller ??
//             TextEditingController(
//               text: initialValue,
//             ),
//         onChanged: (value) => _value = onChange?.call(initialValue, value) ?? value,
//         onSubmitted: (value) => onSubmitted?.call(initialValue, _value = value),
//       ),
//       trailing: onRemove != null
//           ? IconButton(
//               onPressed: () => onRemove!.call(initialValue, _value),
//               icon: const Icon(Icons.remove),
//             )
//           : null,
//       leading: onDuplicate != null
//           ? IconButton(
//               onPressed: () => onDuplicate!.call(initialValue, _value),
//               icon: const Icon(Icons.remove),
//             )
//           : null,
//     );
//   }
// }

class WTagItem extends StatefulWidget {
  final String initialValue;
  final void Function(String initialValue, String value)? onRemove;
  final void Function(String initialValue, String value)? onDuplicate;
  // final String? Function(String initialValue, String value)? onChange;
  final String? Function(
      String initialValue, String priorValue, String newValue)? onChange;
  final bool? Function(String initialValue, String value)? onSubmitted;
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
  bool? wasSubmittedSuccessfully;
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
              : !(wasSubmittedSuccessfully ?? true)
                  ? widget.onSubmitted?.call(widget.initialValue, this.value)
                  : "";
        }
      },
      title: TextField(
        inputFormatters: [
          TextInputFormatter.withFunction(
            (oldValue, newValue) =>
                newValue.text.contains(RegExp(r"\s")) ? oldValue : newValue,
          )
        ],
        controller: TextEditingController(
          text: widget.initialValue,
        ),
        onChanged: (value) {
          final result =
              widget.onChange?.call(widget.initialValue, this.value, value) ??
                  value;
          if (result != this.value) {
            this.value = result;
            wasSubmittedSuccessfully = false;
          }
        },
        onTapOutside: (event) => value.isEmpty
            ? widget.onRemove?.call(widget.initialValue, value)
            : wasSubmittedSuccessfully =
                widget.onSubmitted?.call(widget.initialValue, value),
        onSubmitted: (value) => wasSubmittedSuccessfully =
            widget.onSubmitted?.call(widget.initialValue, value),
      ),
      trailing: widget.onRemove != null
          ? IconButton(
              onPressed: () =>
                  widget.onRemove!.call(widget.initialValue, value),
              icon: const Icon(Icons.remove),
            )
          : null,
      leading: widget.onDuplicate != null
          ? IconButton(
              onPressed: () =>
                  widget.onDuplicate!.call(widget.initialValue, value),
              icon: const Icon(Icons.copy),
            )
          : null,
    );
  }
}

// typedef EditPostPage
class EditPostPageLoader extends StatelessWidget
    implements IRoute<EditPostPageLoader> {
  static lm.FileLogger get logger => _EditPostPageState.logger;
  static const routeNameString = "/post_edit";
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
            future: e621.sendRequest(e621.initPostGet(
              postId!,
              credentials: E621AccessData.fallbackForced?.cred,
            )),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return EditPostPage(
                    post: E6PostResponse.fromRawJson(snapshot.data!.body));
              } else if (snapshot.hasError) {
                return ErrorPage(
                  error: snapshot.error,
                  stackTrace: snapshot.stackTrace,
                  logger: logger,
                );
              } else {
                return util.fullPageSpinner;
              }
            },
          );
  }
}
