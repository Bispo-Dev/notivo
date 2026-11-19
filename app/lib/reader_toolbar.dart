import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'design.dart';
import 'strings.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.tool,
    required this.color,
    required this.colors,
    required this.onTool,
    required this.onColor,
    required this.onCustom,
    required this.onUndo,
    required this.onRedo,
    required this.onSize,
    required this.onMore,
    this.size = 1,
    this.exporting = false,
  });
  final String tool;
  final Color color;
  final List<Color> colors;
  final ValueChanged<String> onTool;
  final ValueChanged<Color> onColor;
  final VoidCallback onCustom, onUndo, onRedo, onSize, onMore;
  // Stroke width multiplier, shown as a dot that grows with it.
  final double size;
  final bool exporting;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final c = NotivoColors(context);
      final compact = bounds.maxWidth < 700;
      final tools = [
        for (final entry in [
          ('navigate', LucideIcons.hand, 'Navegar'),
          ('pen', LucideIcons.pencil, 'Caneta'),
          ('highlighter', LucideIcons.highlighter, 'Grifador'),
          ('eraser', LucideIcons.eraser, 'Borracha'),
        ])
          DesignIcon(
            icon: entry.$2,
            label: tr(context, entry.$3),
            onPressed: () => onTool(entry.$1),
            color: tool == entry.$1 ? c.accent : c.tx,
            background: tool == entry.$1 ? c.active : null,
          ),
      ];
      final actions = [
        DesignIcon(
          icon: LucideIcons.undo2,
          label: tr(context, 'Desfazer'),
          onPressed: onUndo,
        ),
        DesignIcon(
          icon: LucideIcons.redo2,
          label: tr(context, 'Refazer'),
          onPressed: onRedo,
        ),
        exporting
            ? const SizedBox.square(
                dimension: 44,
                child: Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : DesignIcon(
                icon: LucideIcons.ellipsis,
                label: tr(context, 'Mais opções'),
                onPressed: onMore,
              ),
      ];
      Widget swatch(Color? value) {
        void select() => value == null ? onCustom() : onColor(value);
        final visual = AnnotationSwatch(
          color: value,
          selected: value == null ? !colors.contains(color) : color == value,
          onTap: select,
        );
        return Semantics(
          button: true,
          label: tr(
            context,
            value == null ? 'Escolher outra cor' : 'Cor de anotação',
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: select,
            child: SizedBox.square(
              dimension: 44,
              child: Center(child: IgnorePointer(child: visual)),
            ),
          ),
        );
      }

      final thickness = Tooltip(
        message: tr(context, 'Espessura do traço'),
        child: Semantics(
          button: true,
          label: tr(context, 'Espessura do traço'),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onSize,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 2 + 8 * size,
                    height: 2 + 8 * size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.tx,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final palette = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 2,
        children: [
          for (final value in colors) swatch(value),
          swatch(null),
          thickness,
        ],
      );
      Widget separator() => Container(
        width: 1,
        height: 24,
        color: c.line,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
      return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 8 : 0,
          ),
          // shortcut: under ~344 px wide the rows scale down, so targets shrink below 44 px.
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        spacing: 2,
                        children: [...tools, ...actions],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(fit: BoxFit.scaleDown, child: palette),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 2,
                  children: [
                    ...tools,
                    separator(),
                    palette,
                    separator(),
                    ...actions,
                  ],
                ),
      );
    },
  );
}
