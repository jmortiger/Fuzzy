import 'package:flutter/material.dart';
import 'package:fuzzy/util/util.dart' as util;
import 'package:fuzzy/web/e621/e621_access_data.dart';
import 'package:j_util/e621.dart' as e621;
import 'package:fuzzy/log_management.dart' as lm;
import 'package:j_util/j_util_full.dart';

class WCreateSet extends StatefulWidget {
  const WCreateSet({super.key});

  @override
  State<WCreateSet> createState() => _WCreateSetState();
}

class _WCreateSetState extends State<WCreateSet> {
  // #region Logger
  static lm.Printer get print => lRecord.print;
  static lm.FileLogger get logger => lRecord.logger;
  // ignore: unnecessary_late
  static late final lRecord = lm.genLogger("WCreateSet");
  // #endregion Logger
  String postSetName = "";
  String postSetShortname = "";
  String? postSetDescription;
  bool? postSetIsPublic;
  bool? postSetTransferOnDelete;
  String? postSetNameErrorText;
  String? postSetShortnameErrorText;
  String? postSetDescriptionErrorText;
  String? determineNameErrorText(String value) =>
      value.length < 3 || value.length > 100
          ? "must be between three and one hundred characters long"
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                postSetName = value;
                postSetNameErrorText = determineNameErrorText(value);
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "Set Name",
                errorText: postSetNameErrorText,
                counterText: "${postSetName.length}/100",
              ),
              maxLength: 100,
            ),
            TextField(
              onChanged: (value) {
                postSetShortname = value;
                postSetShortnameErrorText = determineShortnameErrorText(value);
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "Set Shortname",
                errorText: postSetShortnameErrorText,
                counterText: "${postSetShortname.length}/50",
              ),
              maxLength: 50,
            ),
            TextField(
              onChanged: (value) {
                postSetDescription = value;
                // postSetDescriptionErrorText =
                //     determineDescriptionErrorText(value);
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "Set Description",
                errorText: postSetDescriptionErrorText,
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
                  onPressed: () async {
                    final r = e621.Api.initCreateSetRequest(
                      postSetName: postSetName,
                      postSetShortname: postSetShortname,
                      postSetDescription: postSetDescription,
                      postSetIsPublic: postSetIsPublic,
                      postSetTransferOnDelete: postSetTransferOnDelete,
                      credentials: E621AccessData.fallback?.cred,
                    );
                    util.logRequest(r, logger, lm.LogLevel.INFO);
                    if ((determineNameErrorText(postSetName) ??
                            determineShortnameErrorText(postSetShortname)) !=
                        null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                        "Resolve Errors with Name and/or shortname",
                      )));
                      return;
                    }
                    final res = await e621.Api.sendRequest(r);
                    util.logResponse(res, logger, lm.LogLevel.INFO);
                    if (res.statusCodeInfo.isSuccessful) {
                      if (mounted) {
                        Navigator.pop(this.context);
                      }
                    }
                  },
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
    );
  }
}
