import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'strings.dart';

/// Values transcribed from the eight artboards in docs/notivo-telas.html.
class NotivoColors {
  NotivoColors(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get bg => dark ? const Color(0xff14102a) : Colors.white;
  Color get card => dark ? const Color(0xff1b1636) : Colors.white;
  Color get soft => dark ? const Color(0xff1f1940) : const Color(0xfff4effc);
  Color get ink => dark ? const Color(0xfff1ebff) : const Color(0xff1f1340);
  Color get tx => dark ? const Color(0xfff1ebff) : const Color(0xff2e1a6b);
  Color get tx2 => dark ? const Color(0xffb3a6d9) : const Color(0xff5b4d85);
  Color get line => dark ? const Color(0xff2e2552) : const Color(0xffe6ddf7);
  Color get rowLine => dark ? const Color(0xff241d45) : const Color(0xffefe9fa);
  Color get outline => dark ? const Color(0xff3f3470) : const Color(0xffd9ccf5);
  Color get accent => dark ? const Color(0xffb79cf0) : const Color(0xff6d3bd2);
  Color get active => dark ? const Color(0xff2e2552) : const Color(0xffede5fb);
  Color get mark => dark ? const Color(0xffc9b6f5) : const Color(0xff6d3bd2);
  Color get banda => dark ? const Color(0xff4b2a9b) : const Color(0xff2e1a6b);
}

TextStyle designText(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  String family = 'Inter',
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  height: height,
  color: color,
);

class DesignViewport extends StatelessWidget {
  const DesignViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(size: Size(bounds.maxWidth, bounds.maxHeight)),
        child: SizedBox.expand(child: child),
      );
    },
  );
}

class DesignIcon extends StatelessWidget {
  const DesignIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.background,
    this.size = 22,
    this.extent = 44,
    this.radius = 12,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color, background;
  final double size, extent, radius;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tr(context, label),
    child: Semantics(
      button: true,
      label: tr(context, label),
      child: Material(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox.square(
            dimension: extent,
            child: Icon(
              icon,
              size: size,
              color: color ?? NotivoColors(context).tx,
            ),
          ),
        ),
      ),
    ),
  );
}

class DesignButton extends StatelessWidget {
  const DesignButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fill,
    this.color,
    this.outlined = false,
    this.weight = FontWeight.w500,
    this.horizontal = 18,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? fill, color;
  final bool outlined;
  final FontWeight weight;
  final double horizontal;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final fg = color ?? c.accent;
    return Material(
      color: fill ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: outlined ? BorderSide(color: c.outline) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(
            horizontal: horizontal + (outlined ? 1 : 0),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                tr(context, label),
                style: designText(15, fg, weight: weight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryLayout extends StatelessWidget {
  const LibraryLayout({
    super.key,
    required this.brand,
    required this.onCreate,
    required this.cards,
    this.onBrowseAll,
    this.onMenu,
    this.picking = false,
    this.bottomPadding = 40,
  });
  final Widget brand;
  final VoidCallback onCreate;
  final List<Widget> cards;
  final VoidCallback? onBrowseAll;
  final VoidCallback? onMenu;
  final bool picking;
  final double bottomPadding;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600 || size.height < 500;
    final gutter = compact ? (size.width < 360 ? 16.0 : 20.0) : 40.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, compact ? 24 : 64, gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                if (onMenu != null) ...[
                  DesignIcon(
                    icon: picking
                        ? LucideIcons.chevronLeft
                        : LucideIcons.ellipsisVertical,
                    label: picking ? 'Voltar' : 'Menu',
                    onPressed: onMenu!,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(fit: BoxFit.scaleDown, child: brand),
                  ),
                ),
                const SizedBox(width: 12),
                if (size.width < 420)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: c.outline),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: DesignIcon(
                      label: 'Nova coleção', icon: LucideIcons.plus,
                      onPressed: onCreate, color: c.accent, radius: 22,
                    ),
                  )
                else
                  DesignButton(
                    label: 'Nova coleção',
                    onPressed: onCreate,
                    icon: LucideIcons.plus,
                    outlined: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 23.8,
            child: Text(
              tr(context, 'Suas partituras, sempre à mão.'),
              style: designText(
                17,
                c.tx2,
                height: 1.4,
                family: 'Source Serif 4',
              ),
            ),
          ),
          SizedBox(height: compact ? 32 : 56),
          Expanded(
            child: cards.isEmpty
                ? SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.bookOpen, size: 44, color: c.mark),
                          const SizedBox(height: 16),
                          Text(
                            tr(context, 'Nenhuma coleção ainda'),
                            style: designText(
                              20,
                              c.tx,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              context,
                              'Crie uma coleção para organizar suas partituras.',
                            ),
                            textAlign: TextAlign.center,
                            style: designText(14, c.tx2),
                          ),
                          if (onBrowseAll != null)
                            TextButton(
                              onPressed: onBrowseAll,
                              child: Text(tr(context, 'Ver partituras')),
                            ),
                        ],
                      ),
                    ),
                  )
                : GridView(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size.width >= 1100 ? 3 : 2,
                      crossAxisSpacing: compact ? 12 : 16,
                      mainAxisSpacing: compact ? 12 : 16,
                      mainAxisExtent: compact ? 180 : 300,
                    ),
                    children: cards,
                  ),
          ),
        ],
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.name,
    required this.count,
    required this.icon,
    required this.color,
    required this.onOpen,
    this.onEdit,
    this.onLongPress,
    this.selected = false,
    this.iconColor = Colors.white,
  });
  final String name;
  final int count;
  final IconData icon;
  final Color color, iconColor;
  final VoidCallback onOpen;
  final VoidCallback? onEdit, onLongPress;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < 600 || viewport.height < 500;
    return Material(
      color: selected ? c.active : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? c.accent : c.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(compact ? 20 : 29),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 44 : 52,
                    height: compact ? 44 : 52,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(LucideIcons.circleCheck, size: 24, color: c.accent)
                  else if (onEdit != null)
                    DesignIcon(
                      icon: LucideIcons.ellipsis,
                      label: 'Ações da coleção',
                      onPressed: onEdit,
                      size: 20,
                      color: c.tx2,
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: designText(
                      compact ? (viewport.width < 360 ? 18 : 20) : 28,
                      c.tx,
                      weight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count ${tr(context, count == 1 ? 'partitura' : 'partituras')}',
                    style: designText(14, c.tx2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScoreRow extends StatelessWidget {
  const ScoreRow({
    super.key,
    required this.name,
    required this.collections,
    required this.selected,
    required this.onSelect,
    required this.onMenu,
    this.onTap,
    this.onLongPress,
  });
  final String name, collections;
  final bool selected;
  final VoidCallback onSelect, onMenu;
  final VoidCallback? onTap, onLongPress;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Material(
      color: selected ? c.soft : Colors.transparent,
      borderRadius: BorderRadius.circular(selected ? 14 : 0),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: 72,
          padding: const EdgeInsets.only(left: 2, right: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.transparent : c.rowLine,
              ),
            ),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                selected: selected,
                label: tr(context, 'Selecionar'),
                child: GestureDetector(
                onTap: onSelect,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? const Color(0xff6d3bd2) : null,
                    border: selected
                        ? null
                        : Border.all(color: c.outline, width: 1.5),
                  ),
                  child: selected
                      ? const Icon(
                          LucideIcons.check,
                          size: 15,
                          color: Colors.white,
                        )
                      : null,
                ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: designText(17, c.ink, weight: FontWeight.w500),
                    ),
                    Text(
                      collections,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: designText(13, c.tx2),
                    ),
                  ],
                ),
              ),
              DesignIcon(
                icon: LucideIcons.ellipsisVertical,
                label: 'Ações da partitura',
                onPressed: onMenu,
                color: c.tx2,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectionPill extends StatelessWidget {
  const SelectionPill({
    super.key,
    required this.count,
    required this.onClear,
    required this.onOpen,
    required this.onAdd,
  });
  final int count;
  final VoidCallback onClear, onOpen, onAdd;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final compact = bounds.maxWidth < 500;
      return Container(
        height: 64,
        padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 0, 10, 0),
        decoration: BoxDecoration(
          color: const Color(0xff2e1a6b),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff2e1a6b).withValues(alpha: .3),
              offset: const Offset(0, 8),
              blurRadius: 28,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: tr(context, 'Adicionar partituras de outras coleções'),
                child: InkWell(
                  onTap: onAdd,
                  child: Text(
                    bounds.maxWidth < 360
                        ? '$count ${tr(context, 'sel.')}'
                        : '$count ${tr(context, 'selecionadas')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: designText(
                      16,
                      Colors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            DesignButton(
              label: 'Limpar',
              onPressed: onClear,
              horizontal: compact ? 10 : 14,
              color: const Color(0xffc9b6f5),
            ),
            const SizedBox(width: 8),
            DesignButton(
              label: 'Abrir em abas',
              onPressed: onOpen,
              horizontal: compact ? 14 : 22,
              fill: const Color(0xffc9b6f5),
              color: const Color(0xff2e1a6b),
              weight: FontWeight.w600,
            ),
          ],
        ),
      );
    },
  );
}

class AnnotationSwatch extends StatelessWidget {
  const AnnotationSwatch({
    super.key,
    this.color,
    this.selected = false,
    required this.onTap,
  });
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tr(
      context,
      color == null ? 'Cor personalizada (RGB)' : 'Cor da anotação',
    ),
    child: Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 26,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    gradient: color == null
                        ? const SweepGradient(
                            transform: GradientRotation(-1.5707963267948966),
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
                    border: Border.all(
                      color: NotivoColors(context).line,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: -4,
                  top: -4,
                  right: -4,
                  bottom: -4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xff2e1a6b),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DesignPill extends StatelessWidget {
  const DesignPill({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(32)),
  });
  final Widget child;
  final BorderRadius radius;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.line),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2e1a6b).withValues(alpha: .12),
            offset: const Offset(0, 8),
            blurRadius: 28,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Top bar shown while items are picked by long press, to remove them.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.onDelete,
  });
  final int count;
  final VoidCallback onClose, onDelete;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          DesignIcon(icon: LucideIcons.x, label: 'Cancelar', onPressed: onClose),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count ${tr(context, 'selecionadas')}',
              style: designText(18, c.tx, weight: FontWeight.w600),
            ),
          ),
          DesignIcon(
            icon: LucideIcons.trash2,
            label: 'Remover',
            onPressed: count == 0 ? null : onDelete,
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}
