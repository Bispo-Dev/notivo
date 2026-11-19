import 'package:flutter/material.dart';

import 'design.dart';
import 'strings.dart';

/// Opens an HSV color picker. Cancel closes with null; Use returns an opaque RGB color.
class ColorPickerSheet extends StatefulWidget {
  const ColorPickerSheet({super.key, required this.initial});

  final Color initial;

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    // Annotation colors are RGB; incoming alpha is intentionally discarded.
    final hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();
  String get _hex =>
      '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _setSV(Offset position, Size size) {
    setState(() {
      _saturation = (position.dx / size.width).clamp(0.0, 1.0).toDouble();
      _value = (1 - position.dy / size.height).clamp(0.0, 1.0).toDouble();
    });
  }

  void _setHue(Offset position, Size size) {
    setState(
      () => _hue =
          ((position.dx - 14) / (size.width - 28)).clamp(0.0, 1.0).toDouble() *
          360,
    );
  }

  Widget _svSurface() => LayoutBuilder(
    builder: (context, bounds) {
      final size = Size(bounds.maxWidth, bounds.maxHeight);
      return Semantics(
        label: tr(context, 'Campo de saturação e brilho'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (event) => _setSV(event.localPosition, size),
          onPanUpdate: (event) => _setSV(event.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _SaturationValuePainter(_hue)),
                Positioned(
                  left: (_saturation * size.width - 12)
                      .clamp(0.0, size.width - 24)
                      .toDouble(),
                  top: ((1 - _value) * size.height - 12)
                      .clamp(0.0, size.height - 24)
                      .toDouble(),
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _color,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _hueControl(NotivoColors colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr(context, 'Matiz'),
        style: designText(13, colors.tx2, weight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, bounds) {
          final size = Size(bounds.maxWidth, 44);
          return Semantics(
            label: tr(context, 'Faixa de matiz'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (event) => _setHue(event.localPosition, size),
              onPanUpdate: (event) => _setHue(event.localPosition, size),
              child: SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xffff0000),
                                Color(0xffffff00),
                                Color(0xff00ff00),
                                Color(0xff00ffff),
                                Color(0xff0000ff),
                                Color(0xffff00ff),
                                Color(0xffff0000),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (_hue / 360 * (size.width - 28))
                          .clamp(0.0, size.width - 28)
                          .toDouble(),
                      child: IgnorePointer(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HSVColor.fromAHSV(1, _hue, 1, 1).toColor(),
                            border: Border.all(color: colors.card, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .22),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _preview(NotivoColors colors) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outline),
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'RGB'), style: designText(12, colors.tx2)),
          Text(_hex, style: designText(15, colors.tx, weight: FontWeight.w500)),
        ],
      ),
    ],
  );

  Widget _actions(NotivoColors colors) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: colors.tx,
            side: BorderSide(color: colors.outline),
            textStyle: designText(14, colors.tx, weight: FontWeight.w500),
          ),
          child: Text(tr(context, 'Cancelar')),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 44),
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            textStyle: designText(14, Colors.white, weight: FontWeight.w600),
          ),
          child: Text(tr(context, 'Usar cor')),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = NotivoColors(context);
    final media = MediaQuery.sizeOf(context);
    final compactLandscape = media.width > media.height && media.height < 500;
    final maxHeight = (media.height * .9).clamp(0.0, 900.0).toDouble();

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Saturação e brilho'),
          style: designText(13, colors.tx2, weight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        if (compactLandscape)
          SizedBox(height: 180, child: _svSurface())
        else
          AspectRatio(aspectRatio: 1.8, child: _svSurface()),
      ],
    );

    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hueControl(colors),
        const SizedBox(height: 12),
        _preview(colors),
        const SizedBox(height: 12),
        _actions(colors),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'Escolher cor'),
              style: designText(24, colors.tx, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (compactLandscape)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: field),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: controls),
                ],
              )
            else ...[
              field,
              const SizedBox(height: 14),
              controls,
            ],
          ],
        ),
      ),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.hue);
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [Colors.white, base])
            .createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      hue != oldDelegate.hue;
}
