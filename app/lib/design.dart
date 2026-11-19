import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';

import 'strings.dart';

/// Design tokens of the 834 × 1194 tablet reference layout.
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

/// Rounded search box used by the library, collections and long sheets.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.height = 48,
  });
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(LucideIcons.search, size: 20, color: c.tx2),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: designText(16, c.tx),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: designText(16, c.tx2),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal + (outlined ? 1 : 0),
          ),
          // No alignment: it would stretch the button to the parent height.
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

/// Home screen layout: header, search, recent scores and the collections.
/// When [results] is given (a search or "all scores"), it replaces the sections.
class LibraryLayout extends StatelessWidget {
  const LibraryLayout({
    super.key,
    required this.brand,
    required this.onCreate,
    required this.cards,
    this.onImport,
    this.onMenu,
    this.picking = false,
    this.bottomPadding = 40,
    this.search,
    this.recents = const [],
    this.onSeeAll,
    this.results,
  });
  final Widget brand;
  final VoidCallback onCreate;
  final List<Widget> cards;
  final VoidCallback? onImport;
  // Opens Settings, or goes back when picking scores for the reader.
  final VoidCallback? onMenu;
  final bool picking;
  final double bottomPadding;
  final Widget? search;
  final List<Widget> recents;
  final VoidCallback? onSeeAll;
  final Widget? results;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600 || size.height < 500;
    final gutter = compact ? (size.width < 360 ? 16.0 : 20.0) : 40.0;
    Widget heading(String text, Widget? trailing) => Row(
      children: [
        Expanded(
          child: Text(
            tr(context, text),
            style: designText(compact ? 16 : 18, c.tx, weight: FontWeight.w600),
          ),
        ),
        ?trailing,
      ],
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        compact ? 16 : 48,
        gutter,
        bottomPadding,
      ),
      children: [
        Row(
          spacing: 8,
          children: [
            if (picking && onMenu != null)
              DesignIcon(
                icon: LucideIcons.chevronLeft,
                label: 'Voltar',
                onPressed: onMenu,
              ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: brand),
              ),
            ),
            if (!picking && onMenu != null)
              DesignIcon(
                icon: LucideIcons.settings,
                label: 'Configurações',
                onPressed: onMenu,
                radius: 22,
              ),
            if (onImport != null)
              size.width < 600
                  ? DesignIcon(
                      label: 'Importar PDFs',
                      icon: LucideIcons.fileUp,
                      onPressed: onImport,
                      color: Theme.of(context).colorScheme.onPrimary,
                      background: c.accent,
                      radius: 22,
                      size: 20,
                    )
                  : DesignButton(
                      label: 'Importar PDFs',
                      onPressed: onImport!,
                      icon: LucideIcons.fileUp,
                      fill: c.accent,
                      color: Theme.of(context).colorScheme.onPrimary,
                      weight: FontWeight.w600,
                    ),
          ],
        ),
        SizedBox(height: compact ? 16 : 28),
        if (search != null) search!,
        SizedBox(height: compact ? 20 : 28),
        if (results != null)
          results!
        else ...[
          if (recents.isNotEmpty) ...[
            heading(
              'Abertas recentemente',
              onSeeAll == null
                  ? null
                  : TextButton(
                      onPressed: onSeeAll,
                      child: Text(tr(context, 'Ver todas')),
                    ),
            ),
            const SizedBox(height: 12),
            compact
                ? SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: recents.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) =>
                          SizedBox(width: 110, child: recents[i]),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Expanded(
                          child: i < recents.length
                              ? recents[i]
                              : const SizedBox(),
                        ),
                    ],
                  ),
            SizedBox(height: compact ? 24 : 32),
          ],
          heading(
            'Coleções',
            compact
                ? DesignButton(
                    label: 'Nova',
                    onPressed: onCreate,
                    icon: LucideIcons.plus,
                    outlined: true,
                    horizontal: 14,
                  )
                : DesignButton(
                    label: 'Nova coleção',
                    onPressed: onCreate,
                    icon: LucideIcons.plus,
                    outlined: true,
                  ),
          ),
          const SizedBox(height: 12),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(LucideIcons.bookOpen, size: 44, color: c.mark),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, 'Nenhuma coleção ainda'),
                    style: designText(20, c.tx, weight: FontWeight.w500),
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
                ],
              ),
            )
          else if (compact)
            Column(
              spacing: 10,
              children: [
                for (final card in cards) SizedBox(height: 72, child: card),
              ],
            )
          else
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: size.width >= 1100 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 120,
              ),
              children: cards,
            ),
        ],
      ],
    );
  }
}

/// A collection on the home screen: badge, name and count in one row.
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Material(
      color: selected ? c.active : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        side: BorderSide(
          color: selected ? c.accent : c.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 0, 4, 0),
          child: Row(
            spacing: compact ? 12 : 16,
            children: [
              Container(
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, size: compact ? 20 : 24, color: iconColor),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: designText(
                        compact ? 16 : 20,
                        c.tx,
                        weight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    Text(
                      '$count ${tr(context, count == 1 ? 'partitura' : 'partituras')}',
                      style: designText(compact ? 13 : 14, c.tx2),
                    ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    LucideIcons.circleCheck,
                    size: 24,
                    color: c.accent,
                  ),
                )
              else if (onEdit != null)
                DesignIcon(
                  icon: compact
                      ? LucideIcons.ellipsisVertical
                      : LucideIcons.ellipsis,
                  label: 'Ações da coleção',
                  onPressed: onEdit,
                  size: 20,
                  color: c.tx2,
                  radius: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A recently opened score: its first page, name and where it lives.
class RecentScoreCard extends StatelessWidget {
  const RecentScoreCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.path,
    required this.onTap,
  });
  final String name, subtitle, path;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, bounds) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              // In the phone's fixed-height strip the page shrinks so the
              // two text lines always fit, whatever the font size.
              if (bounds.hasBoundedHeight)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, space) => ScoreThumb(
                      path: path,
                      width: math.min(space.maxWidth, space.maxHeight / 1.35),
                    ),
                  ),
                )
              else
                ScoreThumb(path: path, width: bounds.maxWidth),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: designText(
                  14,
                  c.tx,
                  weight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: designText(12, c.tx2, height: 1.2),
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
    this.path,
    this.onMenu,
    this.onTap,
    this.onLongPress,
  });
  final String name, collections;
  // The PDF, for the first-page thumbnail.
  final String? path;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onMenu, onTap, onLongPress;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    // Square selection band: the row is part of a list, not a card.
    return Material(
      color: selected ? c.soft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(2, 6, 4, 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.transparent : c.rowLine,
              ),
            ),
          ),
          child: Row(
            spacing: 12,
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
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? c.accent : null,
                          border: selected
                              ? null
                              : Border.all(color: c.outline, width: 1.5),
                        ),
                        child: selected
                            ? Icon(
                                LucideIcons.check,
                                size: 14,
                                color: Theme.of(context).colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              if (path != null) ScoreThumb(path: path!, width: 40),
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
                    if (collections.isNotEmpty)
                      Text(
                        collections,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: designText(13, c.tx2),
                      ),
                  ],
                ),
              ),
              if (onMenu != null)
                DesignIcon(
                  icon: LucideIcons.ellipsisVertical,
                  label: 'Ações da partitura',
                  onPressed: onMenu,
                  color: c.tx2,
                  size: 20,
                  radius: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating bar at the bottom while things are selected, the same on every screen.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    this.onDelete,
    this.deleteLabel = 'Remover',
    this.onCollections,
    this.onOpen,
  });
  final int count;
  final VoidCallback onClose;
  final VoidCallback? onDelete, onCollections, onOpen;
  final String deleteLabel;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final narrow = bounds.maxWidth < 380;
      return Container(
        height: 64,
        padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
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
          spacing: 4,
          children: [
            DesignIcon(
              icon: LucideIcons.x,
              label: 'Limpar seleção',
              onPressed: onClose,
              color: Colors.white,
              radius: 22,
              size: 20,
            ),
            Expanded(
              child: Text(
                narrow ? '$count' : '$count ${tr(context, 'selecionadas')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: designText(16, Colors.white, weight: FontWeight.w500),
              ),
            ),
            if (onCollections != null)
              DesignIcon(
                icon: LucideIcons.folderPlus,
                label: 'Adicionar à coleção',
                onPressed: onCollections,
                color: const Color(0xffc9b6f5),
                radius: 22,
                size: 20,
              ),
            if (onDelete != null)
              DesignIcon(
                icon: LucideIcons.trash2,
                label: deleteLabel,
                onPressed: onDelete,
                color: const Color(0xffffb4b0),
                radius: 22,
                size: 20,
              ),
            if (onOpen != null)
              DesignButton(
                label: 'Abrir em abas',
                onPressed: onOpen!,
                horizontal: narrow ? 12 : 20,
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

/// First page of a score, small, for lists and sheets.
class ScoreThumb extends StatelessWidget {
  const ScoreThumb({super.key, required this.path, this.width = 40});
  final String path;
  final double width;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Container(
      width: width,
      height: width * 1.35,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: c.line),
        // Square corners, like the sheet of paper it shows.
        boxShadow: width < 80
            ? null
            : [
                BoxShadow(
                  color: const Color(0xff2e1a6b).withValues(alpha: .08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: PdfDocumentViewBuilder.file(
        path,
        builder: (context, document) => PdfPageView(
          document: document,
          pageNumber: 1,
          maximumDpi: 72,
          // No drop shadow: the frame around the thumbnail is the only edge.
          decoration: const BoxDecoration(color: Colors.white),
        ),
      ),
    );
  }
}

/// One option of a [Segmented] control.
typedef Segment<T> = ({T value, String label, IconData? icon});

/// Pill-shaped single choice (tools, reading mode, theme): the chosen
/// option is a raised chip in the accent color. With [iconsOnly] the
/// labels become tooltips and screen-reader names.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.iconsOnly = false,
  });
  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool iconsOnly;
  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          for (final s in segments) _chip(context, c, s, s.value == value),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, NotivoColors c, Segment<T> s, bool on) {
    final fg = on ? c.accent : c.tx;
    final label = tr(context, s.label);
    final chip = Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: on ? c.card : Colors.transparent,
        elevation: on ? 1 : 0,
        shadowColor: const Color(0x2e2e1a6b),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(s.value),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
            padding: EdgeInsets.symmetric(horizontal: iconsOnly ? 0 : 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (s.icon != null)
                  Icon(s.icon, size: iconsOnly ? 20 : 16, color: fg),
                if (!iconsOnly)
                  Text(
                    label,
                    style: designText(
                      14,
                      fg,
                      weight: on ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return iconsOnly ? Tooltip(message: label, child: chip) : chip;
  }
}
