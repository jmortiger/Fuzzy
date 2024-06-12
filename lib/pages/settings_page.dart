import 'package:flutter/material.dart';
import 'package:fuzzy/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  AppSettings get settings => AppSettings.i;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        actions: const [
          TextButton(onPressed: null, child: Text("Save Settings")),
          TextButton(onPressed: null, child: Text("Restore Settings")),
        ],
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text("General Settings"),
            titleTextStyle: null,
          ),
          _buildFavTags(context),
        ],
      ),
    );
  }

  ListTile _buildFavTags(BuildContext context) {
    return ListTile(
      title: const Text("Favorite Tags"),
      subtitle: Text(settings.favoriteTags.toString()),
      onTap: () {
        final before = settings.favoriteTags.fold(
          "",
          (previousValue, element) => "$previousValue$element\n",
        );
        var t = before;
        var ret = showDialog<String>(
          context: context,
          builder: (context) {
            void Function()? acceptCallback = () {
              Navigator.pop(context, t);
            };
            if (t == before) acceptCallback = null;
            return AlertDialog(
              content: TextField(
                maxLines: null,
                onChanged: (value) {
                  t = value;
                },
                controller: TextEditingController.fromValue(TextEditingValue(
                  text: t,
                  selection:
                      TextSelection(baseOffset: 0, extentOffset: t.length - 1),
                )),
              ),
              actions: [
                TextButton(
                  onPressed: acceptCallback,
                  child: const Text("Accept"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, "");
                  },
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
        ret.then<void>((value) {
          if (value?.isNotEmpty ?? false) {
            print("Before: ${settings.favoriteTags.toString()}");
            if (settings.favoriteTags.isNotEmpty) settings.favoriteTags.clear();
            settings.favoriteTags.addAll(value!.split("\n"));
            print("After: ${settings.favoriteTags.toString()}");
          }
        }).onError((error, stackTrace) {
          print(error);
        });
      },
      titleTextStyle: null,
    );
  }
}
