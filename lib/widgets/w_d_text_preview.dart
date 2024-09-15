import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/log_management.dart' as lm;
import 'package:fuzzy/web/e621/dtext_formatter.dart' as dtext;
import 'package:j_util/j_util_widgets.dart';

class WDTextPreview extends StatefulWidget {
  final String? initialText;
  final bool makePreviewCollapsible;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final InputDecoration? decoration;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final void Function(String)? onSubmitted;
  final void Function(String, Map<String, dynamic>)? onAppPrivateCommand;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  const WDTextPreview({
    super.key,
    this.initialText,
    this.makePreviewCollapsible = false,
    this.maxLines /*  = 1 */,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.textInputAction = TextInputAction.none,
    this.keyboardType,
    this.decoration = const InputDecoration(labelText: "Input DText here"),
  });

  @override
  State<WDTextPreview> createState() => _WDTextPreviewState();
}

class _WDTextPreviewState extends State<WDTextPreview> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WDTextPreview").logger;
  late TextEditingController ctr;
  @override
  void initState() {
    super.initState();
    ctr = TextEditingController(text: widget.initialText);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.makePreviewCollapsible)
          ExpansionTile(
            title: const Text("Preview"),
            children: [
              SelectorNotifier(
                  value: ctr,
                  selector: (context, value) => value.text,
                  builder: (context, currText, _) => makePreview(currText)),
            ],
          )
        else
          SelectorNotifier(
              value: ctr,
              selector: (context, value) => value.text,
              builder: (context, currText, _) => makePreview(currText)),
        TextField(
          controller: ctr,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          expands: widget.expands,
          maxLength: widget.maxLength,
          maxLengthEnforcement: widget.maxLengthEnforcement,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onSubmitted: widget.onSubmitted,
          onAppPrivateCommand: widget.onAppPrivateCommand,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          decoration: widget.decoration,
        ),
      ],
    );
  }

  Widget makePreview(String currText) =>
      SelectableText.rich(dtext.tryParse(currText, ctx: context) as TextSpan);
}

class WDTextPreviewScrollable extends StatefulWidget {
  final String? initialText;
  // final bool makePreviewCollapsible;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final InputDecoration? decoration;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final void Function(String)? onSubmitted;
  final void Function(String, Map<String, dynamic>)? onAppPrivateCommand;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  const WDTextPreviewScrollable({
    super.key,
    this.initialText,
    // this.makePreviewCollapsible = false,
    this.maxLines /*  = 1 */,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.textInputAction = TextInputAction.none,
    this.keyboardType,
    this.decoration = const InputDecoration(labelText: "Input DText here"),
  });

  @override
  State<WDTextPreviewScrollable> createState() =>
      _WDTextPreviewScrollableState();
}

class _WDTextPreviewScrollableState extends State<WDTextPreviewScrollable> {
  // ignore: unnecessary_late
  static late final logger = lm.generateLogger("WDTextPreview").logger;
  late TextEditingController ctr;
  @override
  void initState() {
    super.initState();
    ctr = TextEditingController(text: widget.initialText);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: SingleChildScrollView(child: _rootNotifier())),
        TextField(
          controller: ctr,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          expands: widget.expands,
          maxLength: widget.maxLength,
          maxLengthEnforcement: widget.maxLengthEnforcement,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onSubmitted: widget.onSubmitted,
          onAppPrivateCommand: widget.onAppPrivateCommand,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          decoration: widget.decoration,
        ),
      ],
    );
  }

  // StatefulWidget _temp() {
  //   return widget.makePreviewCollapsible
  //       ? ExpansionTile(
  //           title: const Text("Preview"),
  //           children: [_rootNotifier()],
  //         )
  //       : _rootNotifier();
  // }

  SelectorNotifier<TextEditingController, String> _rootNotifier() {
    return SelectorNotifier(
        value: ctr,
        selector: (context, value) => value.text,
        builder: (context, currText, _) {
          return SelectableText.rich(
              dtext.tryParse(currText, ctx: context) as TextSpan);
        });
  }
}
