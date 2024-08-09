import 'package:flutter/material.dart';

class WBackButton extends StatelessWidget {
  const WBackButton({
    super.key,
    this.onPop,
    this.child,
  }) : hover = true;
  const WBackButton.doNotBlockChild({
    super.key,
    this.onPop,
    this.child,
  }) : hover = false;

  final void Function()? onPop;
  final Widget? child;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    final r = Align(
      alignment: AlignmentDirectional.topStart,
      child: SafeArea(
        child: BackButton(
          onPressed: () {
            if (onPop != null) {
              onPop!();
            } else {
              Navigator.pop(context);
            }
          },
          // icon: const Icon(Icons.arrow_back),
          // iconSize: 36,
          style: const ButtonStyle(
            iconSize: WidgetStatePropertyAll(36),
            backgroundColor: WidgetStateColor.transparent,
            elevation: WidgetStatePropertyAll(15),
            shadowColor: WidgetStatePropertyAll(Colors.black),
          ),
        ),
      ),
      // child: IconButton(
      //   onPressed: () {
      //     if (onPop != null) {
      //       onPop!();
      //     } else {
      //       Navigator.pop(context);
      //     }
      //   },
      //   icon: const Icon(Icons.arrow_back),
      //   iconSize: 36,
      //   style: const ButtonStyle(
      //     backgroundColor: WidgetStateColor.transparent,
      //     elevation: WidgetStatePropertyAll(15),
      //     shadowColor: WidgetStatePropertyAll(Colors.black),
      //   ),
      // ),
    );
    return child != null
        ? hover
            ? Stack(children: [child!, r])
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [r, Expanded(child: child!)])
        : r;
  }
}
