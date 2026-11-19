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
    // Phones use the full width; tablets get a centered sheet.
    constraints: const BoxConstraints(maxWidth: 560),
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // House rule: a sheet never passes half the screen, drag handle included;
      // longer content scrolls inside it.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(
            0,
            MediaQuery.sizeOf(context).height / 2 - kMinInteractiveDimension,
          ),
        ),
        child: SafeArea(top: false, child: builder(context)),
      ),
    ),
  );
}

/// The one sheet layout of the app: title (and optional supporting line),
/// scrolling content, and a fixed footer with Cancel + the primary action.
/// Action lists pass no [actions]: tapping a row acts and closes.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.list = false,
  });

  final String title;
  final String? subtitle;
  // Shown before the title: a collection preview or a score thumbnail.
  final Widget? leading;
  final Widget child;
  final List<Widget> actions;
  // Rows that reach closer to the edges, like ListTiles.
  final bool list;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The bottom gap keeps scrolled content from running into the header.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  spacing: 14,
                  children: [
                    ?leading,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: designText(
                              20,
                              colors.tx,
                              weight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          if (subtitle != null)
                            Text(subtitle!, style: designText(14, colors.tx2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    list ? 12 : 24,
                    4,
                    list ? 12 : 24,
                    actions.isEmpty ? 16 : 20,
                  ),
                  child: child,
                ),
              ),
              if (actions.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Primary sheet button; [destructive] paints it red for actions that delete.
class SheetPrimary extends StatelessWidget {
  const SheetPrimary(
    this.label, {
    super.key,
    this.onPressed,
    this.destructive = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null,
      child: Text(label),
    );
  }
}

/// One row of an action sheet.
typedef SheetAction<T> = ({
  T value,
  IconData icon,
  String label,
  bool destructive,
});

/// Action sheet: tapping a row closes it with that row's value.
/// Destructive rows go last, below a divider, in red.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetAction<T>> actions,
  String? subtitle,
  Widget? leading,
}) {
  Widget row(BuildContext ctx, SheetAction<T> a) {
    final color = a.destructive
        ? Theme.of(ctx).colorScheme.error
        : NotivoColors(ctx).tx;
    return ListTile(
      minTileHeight: 56,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(a.icon, color: color),
      title: Text(
        a.label,
        style: designText(
          16,
          color,
          weight: a.destructive ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      onTap: () => Navigator.pop(ctx, a.value),
    );
  }

  final safe = actions.where((a) => !a.destructive).toList();
  final danger = actions.where((a) => a.destructive).toList();
  return showAppSheet<T>(
    context,
    builder: (ctx) => AppSheet(
      title: title,
      subtitle: subtitle,
      leading: leading,
      list: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in safe) row(ctx, a),
          if (safe.isNotEmpty && danger.isNotEmpty)
            const Divider(indent: 12, endIndent: 12),
          for (final a in danger) row(ctx, a),
        ],
      ),
    ),
  );
}
