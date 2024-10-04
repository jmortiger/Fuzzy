import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:e621/e621.dart' as e6;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/log_management.dart' show SymbolName;
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dtext;
import 'package:fuzzy/web/e621/e621.dart';
import 'package:fuzzy/widgets/w_back_button.dart';

class WCommentsLoader extends StatefulWidget {
  final int postId;
  final ListTileControlAffinity controlAffinity;

  const WCommentsLoader({
    super.key,
    required this.postId,
    this.controlAffinity = ListTileControlAffinity.leading,
  });

  @override
  State<WCommentsLoader> createState() => _WCommentsLoaderState();
}

class _WCommentsLoaderState extends State<WCommentsLoader> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger((#WCommentsLoader).name).logger;
  Future<List<Widget>>? f;
  List<Widget>? comments;
  Widget? errorPage;
  @override
  void dispose() {
    f?.ignore();
    f = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      controlAffinity: widget.controlAffinity,
      title: comments == null
          ? const Text("Comments")
          : Text("Comments (${comments!.length})"),
      onExpansionChanged: onExpansionChanged,
      // childrenPadding: const EdgeInsets.symmetric(horizontal: 4),
      children: comments ??
          [
            errorPage ??
                const AspectRatio(
                    aspectRatio: 1, child: CircularProgressIndicator()),
          ],
    );
  }

  void onExpansionChanged(value) => f = value && comments == null && f == null
      ? (e6
          .sendRequest(e6.initSearchCommentsRequest(
            searchPostId: widget.postId,
          ))
          .then((v) => e6.Comment.fromRawJsonResults(v.body).map(buildChild))
          .then((v) => util.toListAsync(v))
          .onError(
          (e, s) {
            logger.severe(e, e, s);
            return [];
          },
        )..then((v) => setState(() {
            comments = v.isEmpty ? null : v;
            f = null;
          })).ignore())
      : f;
  @widgetFactory
  Container buildChild(e6.Comment e) => Container(
        decoration: const BoxDecoration(
            border: Border.symmetric(
          horizontal: BorderSide(color: Colors.white70, width: 2),
          vertical: BorderSide(color: Color(0x00000000), width: 4),
        )),
        child: WComment(comment: e),
      );
}

class WCommentsPane extends StatelessWidget {
  final Iterable<e6.Comment> comments;

  const WCommentsPane({super.key, required this.comments});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text("Comments"),
      children: comments.map((e) => WComment(comment: e)).toList(),
    );
  }
}

class WComment extends StatelessWidget {
  /// Normalized percentage of width taken up by the header. Must be <= 1.
  ///
  /// See [FractionallySizedBox].
  final double headerFraction;
  double get bodyFraction => 1 - headerFraction;
  final e6.Comment comment;
  const WComment({
    super.key,
    required this.comment,
    this.headerFraction = .2,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.start,
      // crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisSize: MainAxisSize.max,
      runAlignment: WrapAlignment.start,
      children: [
        // Flexible(
        //   fit: FlexFit.loose,
        //   flex: 3,
        FractionallySizedBox(
          widthFactor: headerFraction,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  comment.creatorName,
                  style: textTheme.headlineSmall,
                ),
                InkWell(
                  onTap: () => util.defaultTryLaunchUrl(Uri.parse(
                    "https://e621.net/comments/${comment.id}",
                  )),
                  child: Text(
                    "#${comment.id}",
                    style: textTheme.labelLarge?.copyWith(
                      color: Theme.of(context)
                          .textButtonTheme
                          .style
                          ?.foregroundColor
                          ?.resolve({}),
                      // ?.textStyle
                      // ?.resolve({})?.color,
                    ),
                  ),
                ),
                // TextButton(
                //   style: util.modifyTextButtonStyle(context,
                //       visualDensity: VisualDensity.compact),
                //   onPressed: () => Navigator.pop(
                //     context,
                //     util.defaultTryLaunchUrl(Uri.parse(
                //       "https://e621.net/comments/${comment.id}",
                //     )),
                //   ),
                //   child: Text("#${comment.id}", style: textTheme.labelLarge),
                // ),
                SelectableText(
                  "C: ${comment.createdAt}",
                  style: textTheme.labelMedium,
                ),
                if (!comment.createdAt.isAtSameMomentAs(comment.updatedAt))
                  SelectableText(
                    "U: ${comment.updatedAt}",
                    style: textTheme.labelMedium,
                  ),
              ],
            ),
          ),
        ),
        // Flexible(
        //   fit: FlexFit.loose,
        //   flex: 7,
        FractionallySizedBox(
          widthFactor: bodyFraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText.rich(
                dtext.parse(comment.body, context) as TextSpan,
                maxLines: null,
                // softWrap: true,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // TODO: Up and down vote
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: SizedBox(
                            width: double.maxFinite,
                            height: double.maxFinite,
                            child: WBackButton(
                              child: WCreateComment.reply(comment: comment),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text("Reply"),
                  )
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WCreateComment extends StatefulWidget {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger((#WCreateComment).name).logger;
  const WCreateComment({
    super.key,
    this.onSubmitted = launchSpinThenPopOnSubmitted,
    required int this.postId,
    this.maxLines,
    this.managedSpinnerState,
    this.initialSpinnerState = false,
  }) : comment = null;
  const WCreateComment.reply({
    super.key,
    required e6.Comment this.comment,
    this.onSubmitted = launchSpinThenPopOnSubmitted,
    this.maxLines,
    this.managedSpinnerState,
    this.initialSpinnerState = false,
  }) : postId = null;

  final e6.Comment? comment;
  final int? postId;
  final int? maxLines;
  final bool? initialSpinnerState;
  final Future<void> Function({
    required BuildContext context,
    required String commentBody,
    required int commentPostId,
    bool? commentDoNotBumpPost,
    bool? commentIsSticky,
    bool? commentIsHidden,
    ValueNotifier<bool>? showSpinner,
  }) onSubmitted;
  final ValueListenable<bool>? managedSpinnerState;
  int get id => postId ?? comment!.postId;
  String? get initialText => comment != null
      ? '[quote]"${comment!.creatorName}":/users/${comment!.creatorId} said:'
          '\n${comment!.body}\n[/quote]\n\n'
      : null;
  static Future<void> launchSpinThenPopOnSubmitted({
    required BuildContext context,
    required String commentBody,
    required int commentPostId,
    bool? commentDoNotBumpPost,
    bool? commentIsSticky,
    bool? commentIsHidden,
    ValueNotifier<bool>? showSpinner,
  }) {
    showSpinner?.value = true;
    return e6
        .sendRequest(e6.initCreateCommentRequest(
      commentBody: commentBody,
      commentPostId: commentPostId,
      commentDoNotBumpPost: commentDoNotBumpPost,
      commentIsHidden: commentIsHidden,
      commentIsSticky: commentIsSticky,
    ))
        .then((value) {
      if (value.statusCode == 201) {
        if (context.mounted) {
          final c = e6.Comment.fromRawJson(value.body),
              out = "Comment #${c.id} Created Successfully!";
          logger.fine(out);
          util.showUserMessage(context: context, content: Text(out));
          Navigator.pop(context, c);
          return;
        }
      }
    }).then((_) => showSpinner?.value = false);
  }

  @override
  State<WCreateComment> createState() => _WCreateCommentState();
}

class _WCreateCommentState extends State<WCreateComment> {
  late TextEditingController _ctr;
  late String body;
  bool? doNotBumpPost, isSticky, isHidden;
  late final ValueListenable<bool>? spinnerState;
  ValueNotifier<bool>? mySpinnerState;
  @override
  void initState() {
    super.initState();
    spinnerState = (widget.managedSpinnerState ??
        (mySpinnerState = widget.initialSpinnerState != null
            ? ValueNotifier<bool>(widget.initialSpinnerState!)
            : null))
      ?..addListener(_l);
    body = widget.initialText ?? "";
    _ctr = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    spinnerState?.removeListener(_l);
    super.dispose();
  }

  void _l() => setState(() {});
  @override
  Widget build(BuildContext context) {
    return (spinnerState?.value ?? false)
        ? const CircularProgressIndicator()
        : SingleChildScrollView(
            child: Column(
              children: [
                SingleChildScrollView(
                  child: Text.rich(dtext.tryParse(body, ctx: context)),
                ),
                SingleChildScrollView(
                  child: TextField(
                    controller: _ctr,
                    decoration: const InputDecoration(labelText: "Body"),
                    maxLines: null,
                    onChanged: (value) => setState(() => body = value),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        widget.onSubmitted(
                          context: context,
                          commentBody: body,
                          commentPostId: widget.id,
                          commentDoNotBumpPost: doNotBumpPost,
                          commentIsHidden: isHidden,
                          commentIsSticky: isSticky,
                          showSpinner: mySpinnerState,
                        );
                      },
                      child: const Text("Submit"),
                    ),
                    WLabeledCheckbox(
                      label: const Text("No bump"),
                      tristate: true,
                      value: doNotBumpPost,
                      onChanged: (v) => setState(() => doNotBumpPost = v),
                    ),
                    if (E621.loggedInUser.isAssigned &&
                        E621.loggedInUser.$.levelString >= e6.UserLevel.janitor)
                      WLabeledCheckbox(
                        label: const Text("Is Sticky"),
                        tristate: true,
                        value: isSticky,
                        onChanged: (v) => setState(() => isSticky = v),
                      ),
                    if (E621.loggedInUser.isAssigned &&
                        E621.loggedInUser.$.levelString >=
                            e6.UserLevel.moderator)
                      WLabeledCheckbox(
                        label: const Text("Is Hidden"),
                        tristate: true,
                        value: isHidden,
                        onChanged: (v) => setState(() => isHidden = v),
                      ),
                  ],
                ),
              ],
            ),
          );
  }
}

class WLabeledSwitch extends StatelessWidget {
  final Widget label;
  final bool value;
  final void Function(bool)? onChanged;
  const WLabeledSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [label, Switch(value: value, onChanged: onChanged)],
      );
}

class WLabeledCheckbox extends StatelessWidget {
  final Widget label;
  final bool? value;
  final bool tristate;
  final void Function(bool?)? onChanged;
  const WLabeledCheckbox({
    super.key,
    required this.label,
    required this.value,
    this.tristate = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        label,
        Checkbox(value: value, onChanged: onChanged, tristate: tristate),
      ]);
}
