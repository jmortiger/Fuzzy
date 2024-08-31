import 'package:flutter/material.dart';
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart';

class WUpdateSet extends StatefulWidget {
  final e621.PostSet? set;
  const WUpdateSet({super.key, required e621.PostSet this.set});
  const WUpdateSet.create({super.key}) : set = null;

  @override
  State<WUpdateSet> createState() => _WUpdateSetState();
}

class _WUpdateSetState extends State<WUpdateSet> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.generateLogger("WCreateSet");
  // #endregion Logger
  String postSetName = "";
  String? get initialPostSetName => widget.set?.name;
  TextEditingController? postSetNameController;
  String postSetShortname = "";
  String? get initialPostSetShortname => widget.set?.shortname;
  TextEditingController? postSetShortnameController;
  String? postSetDescription;
  String? get initialPostSetDescription => widget.set?.description;
  TextEditingController? postSetDescriptionController;
  bool? postSetIsPublic;
  bool? get initialPostSetIsPublic => widget.set?.isPublic;
  bool? postSetTransferOnDelete;
  bool? get initialPostSetTransferOnDelete => widget.set?.transferOnDelete;
  String? postSetNameErrorText;
  String? postSetShortnameErrorText;
  // String? postSetDescriptionErrorText;
  String? determineNameErrorText(String value) =>
      value.length < 3 || value.length > 100
          ? "Value must be between three and one hundred characters long"
          : null;
  // String? determineDescriptionErrorText(String value) =>
  //     value.length < 3 || value.length > 100
  //         ? "must be between three and one hundred characters long"
  //         : null;
  String? determineShortnameErrorText(String value) {
    var total = value.length < 3 || value.length > 50
        ? "Value must be between three and fifty characters long"
        : "";
    total += value.contains(RegExp(r'[^a-z0-9_]'))
        ? "${total.isEmpty ? "Value " : ", "}must only contain numbers, lowercase letters, and underscores"
        : "";
    total += !value.contains(RegExp(r'[a-z_]'))
        ? "${total.isEmpty ? "Value " : ", and "}must contain at least one lowercase letter or underscore"
        : "";
    return total.isNotEmpty ? total : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.set != null) {
      postSetName = widget.set!.name;
      postSetShortname = widget.set!.shortname;
      postSetDescription = widget.set!.description;
      postSetIsPublic = widget.set!.isPublic;
      postSetTransferOnDelete = widget.set!.transferOnDelete;

      postSetNameController = TextEditingController.fromValue(
          TextEditingValue(text: widget.set!.name));
      postSetShortnameController = TextEditingController.fromValue(
          TextEditingValue(text: widget.set!.shortname));
      postSetDescriptionController = TextEditingController.fromValue(
          TextEditingValue(text: widget.set!.description));
    }

    postSetNameErrorText = determineNameErrorText(initialPostSetName ?? "");
    postSetShortnameErrorText =
        determineShortnameErrorText(initialPostSetShortname ?? "");
    // postSetDescriptionErrorText = determineDescriptionErrorText(initialPostSetDescription);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: double.maxFinite,
      child: SingleChildScrollView(
        child: Material(
          child: Column(
            children: [
              TextField(
                controller: postSetNameController,
                onChanged: (value) => setState(() {
                  postSetName = value;
                  postSetNameErrorText = determineNameErrorText(value);
                }),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: "Set Name",
                  errorText: postSetNameErrorText,
                  counterText: "${postSetName.length}/100",
                ),
                maxLength: 100,
              ),
              TextField(
                controller: postSetShortnameController,
                onChanged: (value) => setState(() {
                  postSetShortname = value;
                  postSetShortnameErrorText =
                      determineShortnameErrorText(value);
                }),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: "Set Shortname",
                  errorText: postSetShortnameErrorText,
                  counterText: "${postSetShortname.length}/50",
                ),
                maxLength: 50,
              ),
              TextField(
                controller: postSetDescriptionController,
                onChanged: (value) => setState(() {
                  postSetDescription = value;
                  // postSetDescriptionErrorText =
                  //     determineDescriptionErrorText(value);
                }),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: "Set Description",
                  // errorText: postSetDescriptionErrorText,
                  counterText: postSetDescription?.length.toString(),
                ),
                maxLines: 5,
              ),
              ListTile(
                trailing: Checkbox(
                  value: postSetIsPublic,
                  onChanged: (value) => setState(() {
                    postSetIsPublic = value;
                  }),
                  tristate: true,
                ),
                title: const Text("Is Public?"),
                leading: Text("$postSetIsPublic"),
                subtitle: const Text(
                  "Private sets are only visible to you. Public sets are visible to anyone, but only you and users you assign as maintainers can edit the set. Only accounts three days or older can make public sets.",
                ),
              ),
              ListTile(
                trailing: Checkbox(
                  value: postSetTransferOnDelete,
                  onChanged: (value) => setState(() {
                    postSetTransferOnDelete = value;
                  }),
                  tristate: true,
                ),
                title: const Text("Transfer On Delete?"),
                leading: Text("$postSetTransferOnDelete"),
                subtitle: const Text(
                  'If "Transfer on Delete" is enabled, when a post is deleted from the site, its parent (if any) will be added to this set in its place. Disable if you want posts to simply be removed from this set with no replacement.',
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: postSetNameErrorText == null &&
                            postSetShortnameErrorText == null
                        ? () async {
                            final r = widget.set == null
                                ? e621.initCreateSetRequest(
                                    postSetName: postSetName,
                                    postSetShortname: postSetShortname,
                                    postSetDescription: postSetDescription,
                                    postSetIsPublic: postSetIsPublic,
                                    postSetTransferOnDelete:
                                        postSetTransferOnDelete,
                                    credentials:
                                        E621AccessData.fallbackForced?.cred,
                                  )
                                : e621.initUpdateSetRequest(
                                    widget.set!.id,
                                    postSetName: postSetName,
                                    postSetShortname: postSetShortname,
                                    postSetDescription: postSetDescription,
                                    postSetIsPublic: postSetIsPublic,
                                    postSetTransferOnDelete:
                                        postSetTransferOnDelete,
                                    credentials: E621AccessData.fallback?.cred,
                                  );
                            lm.logRequest(r, logger, lm.LogLevel.INFO);
                            if ((determineNameErrorText(postSetName) ??
                                    determineShortnameErrorText(
                                        postSetShortname)) !=
                                null) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(const SnackBar(
                                    content: Text(
                                  "Resolve Errors with Name and/or shortname",
                                )));
                              return;
                            }
                            final res = await e621.sendRequest(r);
                            lm.logResponse(res, logger, lm.LogLevel.INFO);
                            if (res.statusCodeInfo.isSuccessful) {
                              if (mounted) {
                                Navigator.pop(this.context,
                                    e621.PostSet.fromRawJson(res.body));
                              }
                            }
                          }
                        : null,
                    child: const Text("Accept"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
