import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'design.dart';
import 'strings.dart';

/// Stroke width multiplier range offered by the thickness slider.
const minStrokeSize = 0.3, maxStrokeSize = 2.5;

/// Base stroke widths in PDF points, scaled by the thickness multiplier.
const penWidth = 3.0, highlighterWidth = 18.0, highlighterOpacity = .32;

/// Eraser reach in PDF points around the finger or pen, scaled by its size.
const eraserRadius = 20.0;

/// Menus open just below the line under the 64 px toolbar: the 44 px button
/// sits 10 px above that line, plus the 1 px line and a 4 px gap.
const _belowToolbar = Offset(0, 15);

/// Preset thicknesses offered as one-tap choices; the slider fine-tunes between them.
const strokePresets = [0.5, 0.8, 1.2, 1.7, 2.4];

/// The reader's tool row: tools, the brush (only for pen and highlighter),
/// undo/redo, reading mode and a menu with the rest. Scrolls sideways if
/// the screen is narrower than the row.
class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.tool,
    required this.color,
    required this.colors,
    required this.onTool,
    required this.onColor,
    required this.onCustom,
    required this.onSize,
    required this.onPenOnly,
    required this.onExport,
    this.onUndo,
    this.onRedo,
    this.size = 1,
    this.penOnly = false,
    this.exportProgress,
    this.paged = true,
    this.onPaged,
    this.compact = false,
  });
  final String tool;
  final Color color;
  final List<Color> colors;
  final ValueChanged<String> onTool;
  final ValueChanged<Color> onColor;
  final VoidCallback onCustom, onPenOnly, onExport;
  // Null when there is nothing to undo or redo: shown dimmed.
  final VoidCallback? onUndo, onRedo;
  final ValueChanged<double> onSize;
  // Stroke width multiplier of the current tool.
  final double size;
  final bool penOnly;
  // 0 to 1 while exporting, null otherwise.
  final double? exportProgress;
  // Pages or continuous reading; null [onPaged] hides the choice.
  final bool paged;
  final ValueChanged<bool>? onPaged;
  // Phones: smaller buttons, no hints, reading mode inside the menu.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    // 44 px targets everywhere; phones save room with tighter gaps instead.
    const extent = 44.0;
    // Pen, highlighter and eraser all have a size to pick.
    final drawing = tool != 'navigate';

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: compact ? 2 : 4,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.soft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            spacing: 2,
            children: [
              for (final entry in [
                ('navigate', LucideIcons.hand, 'Navegar'),
                ('pen', LucideIcons.pencil, 'Caneta'),
                ('highlighter', LucideIcons.highlighter, 'Grifador'),
                ('eraser', LucideIcons.eraser, 'Borracha'),
              ])
                DesignIcon(
                  icon: entry.$2,
                  label: entry.$3,
                  onPressed: () => onTool(entry.$1),
                  color: tool == entry.$1 ? c.accent : c.tx,
                  background: tool == entry.$1 ? c.card : null,
                  extent: extent,
                  radius: 10,
                  size: 20,
                ),
            ],
          ),
        ),
        if (drawing)
          _BrushButton(
            tool: tool,
            color: color,
            colors: colors,
            size: size,
            onColor: onColor,
            onCustom: onCustom,
            onSize: onSize,
            compact: compact,
          ),
      ],
    );

    final end = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: compact ? 0 : 2,
      children: [
        DesignIcon(
          icon: LucideIcons.undo2,
          label: 'Desfazer',
          onPressed: onUndo,
          color: onUndo == null ? c.outline : c.tx,
          extent: extent,
          size: 20,
        ),
        DesignIcon(
          icon: LucideIcons.redo2,
          label: 'Refazer',
          onPressed: onRedo,
          color: onRedo == null ? c.outline : c.tx,
          extent: extent,
          size: 20,
        ),
        if (onPaged != null && !compact) ...[
          const SizedBox(width: 6),
          Segmented<bool>(
            value: paged,
            onChanged: onPaged!,
            segments: const [
              (value: true, label: 'Páginas', icon: LucideIcons.bookOpen),
              (value: false, label: 'Contínuo', icon: LucideIcons.scrollText),
            ],
          ),
        ],
        if (exportProgress != null)
          Tooltip(
            message: tr(context, 'Exportando PDF'),
            child: SizedBox.square(
              dimension: extent,
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    value: exportProgress,
                    strokeWidth: 3,
                    semanticsLabel: tr(context, 'Exportando PDF'),
                  ),
                ),
              ),
            ),
          ),
        _moreMenu(context, c, extent),
      ],
    );

    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12),
        child: ConstrainedBox(
          // Fills the bar when it fits, scrolls when it doesn't.
          constraints: BoxConstraints(
            minWidth: math.max(0, bounds.maxWidth - (compact ? 8 : 24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [row, end],
          ),
        ),
      ),
    );
  }

  Widget _moreMenu(BuildContext context, NotivoColors c, double extent) =>
      MenuAnchor(
        alignmentOffset: _belowToolbar,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.card),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        menuChildren: [
          CheckboxMenuButton(
            value: penOnly,
            onChanged: (_) => onPenOnly(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Desenhar só com a caneta'),
                    style: designText(15, c.tx),
                  ),
                  Text(
                    tr(context, 'O dedo rola e vira páginas'),
                    style: designText(12, c.tx2),
                  ),
                ],
              ),
            ),
          ),
          if (compact && onPaged != null) ...[
            const Divider(height: 1),
            for (final (value, icon, label, hint) in [
              (true, LucideIcons.bookOpen, 'Modo páginas', 'Uma página por vez'),
              (false, LucideIcons.scrollText, 'Modo contínuo', 'Role as páginas sem parar'),
            ])
              MenuItemButton(
                leadingIcon: Icon(icon, size: 20, color: c.tx),
                trailingIcon: paged == value
                    ? Icon(LucideIcons.check, size: 18, color: c.accent)
                    : null,
                onPressed: () => onPaged!(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, label), style: designText(15, c.tx)),
                      Text(tr(context, hint), style: designText(12, c.tx2)),
                    ],
                  ),
                ),
              ),
          ],
          const Divider(height: 1),
          MenuItemButton(
            leadingIcon: Icon(LucideIcons.download, size: 20, color: c.tx),
            onPressed: exportProgress == null ? onExport : null,
            child: Text(
              tr(context, 'Exportar PDF com anotações'),
              style: designText(15, c.tx),
            ),
          ),
        ],
        builder: (context, controller, _) => DesignIcon(
          icon: LucideIcons.ellipsis,
          label: 'Mais opções',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          extent: extent,
          size: 20,
        ),
      );
}

/// Chip with the current color and a wave of the current width; opens the brush panel.
class _BrushButton extends StatelessWidget {
  const _BrushButton({
    required this.tool,
    required this.color,
    required this.colors,
    required this.size,
    required this.onColor,
    required this.onCustom,
    required this.onSize,
    required this.compact,
  });
  final String tool;
  final Color color;
  final List<Color> colors;
  final double size;
  final ValueChanged<Color> onColor;
  final VoidCallback onCustom;
  final ValueChanged<double> onSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final highlighter = tool == 'highlighter';
    final eraser = tool == 'eraser';
    final ink = eraser
        ? c.tx2
        : color.withValues(alpha: highlighter ? highlighterOpacity : 1);
    final base = highlighter ? highlighterWidth : penWidth;
    final label = tr(
      context,
      eraser ? 'Tamanho da borracha' : 'Pincel: cor e espessura',
    );
    // The eraser shows its reach as a circle; pens show a stroke.
    Widget eraserDot(double diameter) => Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.active,
        border: Border.all(color: c.tx2, width: 1.5),
      ),
    );
    bool chosen(double preset) => (size - preset).abs() < .05;
    Widget caption(String text) => Text(
      tr(context, text),
      style: designText(12, c.tx2, weight: FontWeight.w600),
    );

    return MenuAnchor(
      alignmentOffset: _belowToolbar,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.card),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: 268,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          eraser
                              ? 'Borracha'
                              : highlighter
                              ? 'Grifador'
                              : 'Caneta',
                        ),
                        style: designText(15, c.tx, weight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      eraser
                          ? '${(eraserRadius * size * 2).round()} pt'
                          : '${(base * size).toStringAsFixed(1)} pt',
                      style: designText(13, c.tx2),
                    ),
                  ],
                ),
                // Painted with the same width and opacity the page will use.
                Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: eraser
                      // Drawn at 60% so the largest size still fits the box.
                      ? Center(child: eraserDot(eraserRadius * size * 1.2))
                      : CustomPaint(
                          painter: _WavePainter(ink, base * size),
                          size: Size.infinite,
                        ),
                ),
                if (eraser)
                  Text(
                    tr(context, 'Passe sobre um traço para apagá-lo inteiro'),
                    style: designText(12, c.tx2),
                  ),
                if (!eraser) caption('Cor'),
                if (!eraser)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final value in colors)
                        _Swatch(
                          color: value,
                          selected: color.toARGB32() == value.toARGB32(),
                          onTap: () => onColor(value),
                        ),
                      _Swatch(
                        selected: !colors.any(
                          (value) => value.toARGB32() == color.toARGB32(),
                        ),
                        onTap: onCustom,
                      ),
                    ],
                  ),
                caption(eraser ? 'Tamanho' : 'Espessura'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final preset in strokePresets)
                      Semantics(
                        button: true,
                        selected: chosen(preset),
                        label: '$label ${(preset * 100).round()}%',
                        excludeSemantics: true,
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => onSize(preset),
                            child: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: chosen(preset) ? c.active : null,
                                border: Border.all(
                                  color: chosen(preset)
                                      ? c.accent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: eraser
                                  ? eraserDot(4 + 10 * preset)
                                  : Container(
                                      width: 4 + 10 * preset,
                                      height: 4 + 10 * preset,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: ink,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    caption('Ajuste fino'),
                    Expanded(
                      child: Slider(
                        value: size.clamp(minStrokeSize, maxStrokeSize),
                        min: minStrokeSize,
                        max: maxStrokeSize,
                        divisions: 22,
                        semanticFormatterCallback: (value) =>
                            '${(value * 100).round()}%',
                        onChanged: onSize,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: controller.isOpen ? c.active : c.card,
            shape: StadiumBorder(side: BorderSide(color: c.outline)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 6, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      if (eraser)
                        SizedBox.square(
                          dimension: 22,
                          child: Center(child: eraserDot(8 + 5 * size)),
                        )
                      else
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(color: c.line),
                          ),
                        ),
                      if (!compact && !eraser)
                        SizedBox(
                          width: 40,
                          height: 18,
                          child: CustomPaint(
                            painter: _WavePainter(
                              ink,
                              math.min(base * size * 1.2, 8),
                            ),
                          ),
                        ),
                      Icon(LucideIcons.chevronDown, size: 16, color: c.tx),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A color dot in the brush panel; no [color] means "pick another color".
class _Swatch extends StatelessWidget {
  const _Swatch({this.color, required this.selected, required this.onTap});
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Semantics(
      button: true,
      selected: selected,
      label: tr(
        context,
        color == null ? 'Escolher outra cor' : 'Cor de anotação',
      ),
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                gradient: color == null
                    ? const SweepGradient(
                        colors: [
                          Color(0xffe53935),
                          Color(0xfffacc15),
                          Color(0xff22a559),
                          Color(0xff2196f3),
                          Color(0xff6d3bd2),
                          Color(0xffe53935),
                        ],
                      )
                    : null,
                border: Border.all(color: c.line),
                boxShadow: selected
                    ? [
                        // Ring with a gap: outer dark ring first, card-colored gap on top.
                        BoxShadow(color: c.tx, spreadRadius: 4),
                        BoxShadow(color: c.card, spreadRadius: 2),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gentle sine stroke across the box, like a line drawn by hand.
class _WavePainter extends CustomPainter {
  const _WavePainter(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2 + 4;
    final amplitude = (size.height / 2 - inset).clamp(0.0, 14.0);
    final path = Path();
    for (var x = inset; x <= size.width - inset; x += 2) {
      final t = (x - inset) / (size.width - 2 * inset);
      final y = size.height / 2 + amplitude * math.sin(t * 3 * math.pi);
      x == inset ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.width != width;
}
