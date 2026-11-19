import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design.dart';

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final colors = NotivoColors(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    constraints: const BoxConstraints(maxWidth: 760),
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: builder(context)),
    ),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = NotivoColors(context);
    final media = MediaQuery.of(context);
    final viewportHeight =
        media.size.height - media.viewInsets.bottom - media.padding.top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = math
            .max(0.0, math.min(constraints.maxHeight, viewportHeight - 16))
            .toDouble();
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: designText(24, colors.tx, weight: FontWeight.w700),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    child: child,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
