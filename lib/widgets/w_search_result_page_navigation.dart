// ignore_for_file: avoid_print

import 'package:flutter/material.dart';

class WSearchResultPageNavigation extends StatelessWidget {
  final void Function()? onPriorPage;
  final void Function()? onNextPage;

  final TextStyle? textStyle;
  final ButtonStyle? buttonStyle;
  const WSearchResultPageNavigation({
    super.key,
    this.onPriorPage,
    this.onNextPage,
    this.textStyle,
    this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
      width: MediaQuery.of(context).size.width,
      child: Row(
        children: [
          TextButton(
            onPressed: onPriorPage,
            style: buttonStyle,
            child: Text("<", style: textStyle),
          ),
          TextButton(
            onPressed: onNextPage,
            style: buttonStyle,
            child: Text(">", style: textStyle),
          ),
        ],
      ),
    );
  }
}
