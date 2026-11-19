import 'package:flutter/material.dart';

// SVG outline data is copied directly from docs/notivo-manual-de-marca.
const _symbolSvgPath =
    r'''M10.00 46.40L9.97 46.75L9.91 47.05L9.79 47.37L9.65 47.65L9.45 47.93L9.24 48.15L8.96 48.38L8.67 48.55L8.34 48.68L8.00 48.77L6.72 48.90L5.58 49.09L4.73 49.29L3.88 49.54L2.79 49.94L1.96 50.30L0.94 50.82L0.17 51.28L-0.52 51.75L-1.01 52.11L-1.64 52.64L-2.23 53.20L-2.64 53.62L-3.15 54.22L-3.61 54.82L-3.92 55.29L-4.31 55.95L-4.71 56.80L-4.96 57.49L-5.15 58.18L-5.28 58.88L-5.34 59.72L-5.32 60.40L-5.23 61.07L-5.07 61.72L-4.80 62.48L-4.50 63.08L-4.14 63.65L-3.72 64.18L-3.13 64.79L-2.58 65.24L-1.98 65.66L-1.37 66.01L-0.73 66.31L-0.22 66.52L0.46 66.74L1.01 66.89L1.76 67.04L2.32 67.13L3.10 67.20L3.69 67.23L4.51 67.22L5.10 67.19L5.93 67.11L6.53 67.02L7.36 66.85L7.95 66.71L8.77 66.47L9.35 66.26L10.16 65.95L10.71 65.70L11.48 65.31L12.00 65.02L12.72 64.57L13.21 64.23L13.87 63.72L14.31 63.35L14.90 62.79L15.30 62.38L15.81 61.79L16.14 61.35L16.57 60.74L16.84 60.27L17.17 59.65L17.46 58.96L17.69 58.29L17.97 57.06L18.00 56.84L18.01 19.68L18.06 19.39L18.12 19.15L18.34 18.67L18.50 18.44L18.70 18.22L19.11 17.89L19.58 17.65L19.86 17.57L20.11 17.53L20.64 17.52L21.15 17.63L21.43 17.74L21.68 17.88L21.92 18.05L22.13 18.25L49.69 46.95L49.92 47.23L50.10 47.54L50.23 47.85L50.31 48.14L50.36 48.48L50.36 48.78L50.31 49.12L50.21 49.46L50.09 49.74L49.91 50.02L49.64 50.33L49.36 50.57L47.95 51.43L47.00 52.11L46.16 52.82L45.39 53.59L44.68 54.42L44.08 55.29L43.81 55.73L43.49 56.35L43.11 57.26L42.85 58.18L42.70 59.11L42.66 60.00L42.69 60.44L42.76 61.03L42.86 61.48L42.98 61.89L43.30 62.69L43.50 63.08L43.74 63.47L44.28 64.18L44.71 64.63L45.04 64.94L45.81 65.52L46.23 65.78L46.82 66.11L47.76 66.51L48.26 66.68L48.97 66.88L50.02 67.09L51.13 67.20L51.93 67.23L52.49 67.22L53.64 67.14L54.81 66.96L55.64 66.79L56.20 66.64L57.35 66.26L57.90 66.05L58.68 65.71L59.74 65.17L60.25 64.87L60.95 64.41L61.88 63.72L62.70 62.99L63.46 62.20L64.13 61.38L64.70 60.52L65.18 59.64L65.55 58.74L65.80 57.85L66.00 56.87L66.00 3.92L65.93 3.24L65.76 2.63L65.48 2.02L65.10 1.47L64.74 1.09L64.30 0.73L63.82 0.44L63.33 0.23L62.79 0.08L62.22 0.01L61.68 0.01L61.12 0.10L60.58 0.26L60.10 0.48L59.62 0.78L59.19 1.16L58.83 1.56L58.52 2.02L58.28 2.54L58.12 3.04L58.03 3.52L58.00 4.00L57.99 38.26L57.92 38.72L57.77 39.12L57.52 39.53L57.22 39.86L56.88 40.12L56.46 40.33L56.02 40.45L55.56 40.49L55.09 40.44L54.64 40.29L54.23 40.06L53.90 39.79L16.67 1.02L16.40 0.80L16.11 0.60L15.80 0.43L15.46 0.27L15.13 0.16L14.78 0.08L14.10 0.00L13.72 0.01L13.39 0.05L13.05 0.12L12.71 0.21L12.38 0.34L12.04 0.51L11.75 0.69L11.46 0.91L11.15 1.20L10.86 1.53L10.62 1.86L10.41 2.23L10.24 2.64L10.12 3.03L10.04 3.45L10.00 3.88L10.00 46.40Z''';
const _horizontalMarkSvgPath =
    r'''M10.00 46.40L9.97 46.75L9.91 47.05L9.79 47.37L9.65 47.65L9.45 47.93L9.24 48.15L8.96 48.38L8.67 48.55L8.34 48.68L8.00 48.77L6.72 48.90L5.58 49.09L4.73 49.29L3.88 49.54L2.79 49.94L1.96 50.30L0.94 50.82L0.17 51.28L-0.52 51.75L-1.01 52.11L-1.64 52.64L-2.23 53.20L-2.64 53.62L-3.15 54.22L-3.61 54.82L-3.92 55.29L-4.31 55.95L-4.71 56.80L-4.96 57.49L-5.15 58.18L-5.28 58.88L-5.34 59.72L-5.32 60.40L-5.23 61.07L-5.07 61.72L-4.80 62.48L-4.50 63.08L-4.14 63.65L-3.72 64.18L-3.13 64.79L-2.58 65.24L-1.98 65.66L-1.37 66.01L-0.73 66.31L-0.22 66.52L0.46 66.74L1.01 66.89L1.76 67.04L2.32 67.13L3.10 67.20L3.69 67.23L4.51 67.22L5.10 67.19L5.93 67.11L6.53 67.02L7.36 66.85L7.95 66.71L8.77 66.47L9.35 66.26L10.16 65.95L10.71 65.70L11.48 65.31L12.00 65.02L12.72 64.57L13.21 64.23L13.87 63.72L14.31 63.35L14.90 62.79L15.30 62.38L15.81 61.79L16.14 61.35L16.57 60.74L16.84 60.27L17.17 59.65L17.46 58.96L17.69 58.29L17.97 57.06L18.00 56.84L18.01 19.68L18.06 19.39L18.12 19.15L18.34 18.67L18.50 18.44L18.70 18.22L19.11 17.89L19.58 17.65L19.86 17.57L20.11 17.53L20.64 17.52L21.15 17.63L21.43 17.74L21.68 17.88L21.92 18.05L22.13 18.25L49.69 46.95L49.92 47.23L50.10 47.54L50.23 47.85L50.31 48.14L50.36 48.48L50.36 48.78L50.31 49.12L50.21 49.46L50.09 49.74L49.91 50.02L49.64 50.33L49.36 50.57L47.95 51.43L47.00 52.11L46.16 52.82L45.39 53.59L44.68 54.42L44.08 55.29L43.81 55.73L43.49 56.35L43.11 57.26L42.85 58.18L42.70 59.11L42.66 60.00L42.69 60.44L42.76 61.03L42.86 61.48L42.98 61.89L43.30 62.69L43.50 63.08L43.74 63.47L44.28 64.18L44.71 64.63L45.04 64.94L45.81 65.52L46.23 65.78L46.82 66.11L47.76 66.51L48.26 66.68L48.97 66.88L50.02 67.09L51.13 67.20L51.93 67.23L52.49 67.22L53.64 67.14L54.81 66.96L55.64 66.79L56.20 66.64L57.35 66.26L57.90 66.05L58.68 65.71L59.74 65.17L60.25 64.87L60.95 64.41L61.88 63.72L62.70 62.99L63.46 62.20L64.13 61.38L64.70 60.52L65.18 59.64L65.55 58.74L65.80 57.85L66.00 56.87L66.00 3.92L65.93 3.24L65.76 2.63L65.48 2.02L65.10 1.47L64.74 1.09L64.30 0.73L63.82 0.44L63.33 0.23L62.79 0.08L62.22 0.01L61.68 0.01L61.12 0.10L60.58 0.26L60.10 0.48L59.62 0.78L59.19 1.16L58.83 1.56L58.52 2.02L58.28 2.54L58.12 3.04L58.03 3.52L58.00 4.00L57.99 38.26L57.92 38.72L57.77 39.12L57.52 39.53L57.22 39.86L56.88 40.12L56.46 40.33L56.02 40.45L55.56 40.49L55.09 40.44L54.64 40.29L54.23 40.06L53.90 39.79L16.67 1.02L16.40 0.80L16.11 0.60L15.80 0.43L15.46 0.27L15.13 0.16L14.78 0.08L14.10 0.00L13.72 0.01L13.39 0.05L13.05 0.12L12.71 0.21L12.38 0.34L12.04 0.51L11.75 0.69L11.46 0.91L11.15 1.20L10.86 1.53L10.62 1.86L10.41 2.23L10.24 2.64L10.12 3.03L10.04 3.45L10.00 3.88L10.00 46.40Z''';
const _horizontalLettersSvgPath =
    r'''M854.1 -276.0Q854.1 -360.0 891.1 -425.0Q928.1 -490.0 992.1 -525.0Q1056.1 -560.0 1135.1 -560.0Q1214.1 -560.0 1278.1 -525.0Q1342.1 -490.0 1379.1 -425.0Q1416.1 -360.0 1416.1 -276.0Q1416.1 -192.0 1378.1 -127.0Q1340.1 -62.0 1274.6 -26.5Q1209.1 9.0 1130.1 9.0Q1052.1 9.0 989.1 -26.5Q926.1 -62.0 890.1 -126.5Q854.1 -191.0 854.1 -276.0ZM1299.1 -276.0Q1299.1 -336.0 1276.1 -377.5Q1253.1 -419.0 1215.1 -440.0Q1177.1 -461.0 1133.1 -461.0Q1089.1 -461.0 1051.6 -440.0Q1014.1 -419.0 992.1 -377.5Q970.1 -336.0 970.1 -276.0Q970.1 -187.0 1015.6 -138.5Q1061.1 -90.0 1130.1 -90.0Q1174.1 -90.0 1212.6 -111.0Q1251.1 -132.0 1275.1 -174.0Q1299.1 -216.0 1299.1 -276.0ZM1652.1 -458.0V-153.0Q1652.1 -122.0 1666.6 -108.5Q1681.1 -95.0 1716.1 -95.0H1786.1V0.0H1696.1Q1619.1 0.0 1578.1 -36.0Q1537.1 -72.0 1537.1 -153.0V-458.0H1472.1V-551.0H1537.1V-688.0H1652.1V-551.0H1786.1V-458.0ZM1866.1 -697.0Q1866.1 -728.0 1887.1 -749.0Q1908.1 -770.0 1939.1 -770.0Q1969.1 -770.0 1990.1 -749.0Q2011.1 -728.0 2011.1 -697.0Q2011.1 -666.0 1990.1 -645.0Q1969.1 -624.0 1939.1 -624.0Q1908.1 -624.0 1887.1 -645.0Q1866.1 -666.0 1866.1 -697.0ZM1995.1 -551.0V0.0H1881.1V-551.0ZM2348.1 -102.0 2504.1 -551.0H2625.1L2415.1 0.0H2279.1L2070.1 -551.0H2192.1ZM2664.1 -276.0Q2664.1 -360.0 2701.1 -425.0Q2738.1 -490.0 2802.1 -525.0Q2866.1 -560.0 2945.1 -560.0Q3024.1 -560.0 3088.1 -525.0Q3152.1 -490.0 3189.1 -425.0Q3226.1 -360.0 3226.1 -276.0Q3226.1 -192.0 3188.1 -127.0Q3150.1 -62.0 3084.6 -26.5Q3019.1 9.0 2940.1 9.0Q2862.1 9.0 2799.1 -26.5Q2736.1 -62.0 2700.1 -126.5Q2664.1 -191.0 2664.1 -276.0ZM3109.1 -276.0Q3109.1 -336.0 3086.1 -377.5Q3063.1 -419.0 3025.1 -440.0Q2987.1 -461.0 2943.1 -461.0Q2899.1 -461.0 2861.6 -440.0Q2824.1 -419.0 2802.1 -377.5Q2780.1 -336.0 2780.1 -276.0Q2780.1 -187.0 2825.6 -138.5Q2871.1 -90.0 2940.1 -90.0Q2984.1 -90.0 3022.6 -111.0Q3061.1 -132.0 3085.1 -174.0Q3109.1 -216.0 3109.1 -276.0Z''';

Path _parseSvgPath(String data) {
  final tokens = RegExp(r'[A-Za-z]|[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?')
      .allMatches(data)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final path = Path();
  var i = 0;
  var command = '';
  var x = 0.0;
  var y = 0.0;
  double number() => double.parse(tokens[i++]);
  bool isCommand(String token) => RegExp(r'^[A-Za-z]$').hasMatch(token);
  while (i < tokens.length) {
    if (isCommand(tokens[i])) command = tokens[i++];
    switch (command) {
      case 'M':
        x = number();
        y = number();
        path.moveTo(x, y);
        command = 'L';
        break;
      case 'L':
        x = number();
        y = number();
        path.lineTo(x, y);
        break;
      case 'Q':
        final cx = number();
        final cy = number();
        x = number();
        y = number();
        path.quadraticBezierTo(cx, cy, x, y);
        break;
      case 'H':
        x = number();
        path.lineTo(x, y);
        break;
      case 'V':
        y = number();
        path.lineTo(x, y);
        break;
      case 'Z':
        path.close();
        command = '';
        break;
      default:
        throw FormatException('Unsupported SVG command: $command');
    }
  }
  return path;
}

final _symbolPath = _parseSvgPath(_symbolSvgPath);
final _horizontalMarkPath = _parseSvgPath(_horizontalMarkSvgPath);
final _horizontalLettersPath = _parseSvgPath(_horizontalLettersSvgPath);
const _symbolViewBox = Rect.fromLTWH(-5.34, 0, 71.34, 67.23);
const _logoViewBox = Rect.fromLTWH(0, -770, 3226, 800);

class _NotivoMarkPainter extends CustomPainter {
  const _NotivoMarkPainter(this.color, {this.iconViewBox = false});
  final Color color;
  final bool iconViewBox;

  @override
  void paint(Canvas canvas, Size size) {
    if (iconViewBox) {
      canvas.save();
      canvas.scale(size.width / 1024);
      canvas.translate(512, 512);
      canvas.scale(7.7511);
      canvas.translate(-32.75, -35.54);
      canvas.drawPath(
        _symbolPath,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
      canvas.restore();
      return;
    }
    final scale = (size.width / _symbolViewBox.width)
        .clamp(0.0, size.height / _symbolViewBox.height)
        .toDouble();
    canvas.save();
    canvas.translate(
      (size.width - _symbolViewBox.width * scale) / 2,
      (size.height - _symbolViewBox.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-_symbolViewBox.left, -_symbolViewBox.top);
    canvas.drawPath(
      _symbolPath,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NotivoMarkPainter oldDelegate) =>
      color != oldDelegate.color;
}

class NotivoMark extends StatelessWidget {
  const NotivoMark({
    super.key,
    required this.size,
    required this.color,
    this.iconViewBox = false,
  });
  final double size;
  final Color color;
  final bool iconViewBox;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Símbolo musical Notivo',
    child: CustomPaint(
      size: Size(
        iconViewBox
            ? size
            : size * _symbolViewBox.width / _symbolViewBox.height,
        size,
      ),
      painter: _NotivoMarkPainter(color, iconViewBox: iconViewBox),
    ),
  );
}

/// Horizontal wordmark drawn from the official outlined SVG, including its N symbol.
class _NotivoWordmarkPainter extends CustomPainter {
  const _NotivoWordmarkPainter(this.color, this.markColor);
  final Color color;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _logoViewBox.width;
    canvas.save();
    canvas.translate(0, (size.height - _logoViewBox.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-_logoViewBox.left, -_logoViewBox.top);
    // The official horizontal SVG applies these transforms to the symbol path.
    canvas.save();
    canvas.translate(0, 30);
    canvas.scale(10.73925);
    canvas.translate(5.34, -67.23);
    canvas.drawPath(
      _horizontalMarkPath,
      Paint()
        ..color = markColor
        ..isAntiAlias = true,
    );
    canvas.restore();
    canvas.drawPath(
      _horizontalLettersPath,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NotivoWordmarkPainter oldDelegate) =>
      color != oldDelegate.color || markColor != oldDelegate.markColor;
}

class NotivoWordmark extends StatelessWidget {
  const NotivoWordmark({
    super.key,
    this.fontSize = 40,
    this.color = const Color(0xff2e1a6b),
    this.markColor = const Color(0xff6d3bd2),
  });
  final double fontSize;
  final Color color;
  final Color markColor;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Notivo',
    child: CustomPaint(
      size: Size(fontSize * 3.226, fontSize),
      painter: _NotivoWordmarkPainter(color, markColor),
    ),
  );
}

class NotivoAppIcon extends StatelessWidget {
  const NotivoAppIcon({
    super.key,
    required this.size,
    required this.background,
    required this.markColor,
  });
  final double size;
  final Color background;
  final Color markColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 276 / 1024),
      ),
      child: Center(
        child: ExcludeSemantics(
          child: NotivoMark(size: size, color: markColor, iconViewBox: true),
        ),
      ),
    ),
  );
}
