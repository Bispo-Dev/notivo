import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'color_picker.dart';
import 'design.dart';
import 'sheets.dart';
import 'strings.dart';

/// Icons offered for collections, stored by key in the database.
/// Edit this list to change the catalog; unknown keys fall back to `music`.
const collectionIcons = <String, IconData>{
  'music': LucideIcons.music,
  'music-2': LucideIcons.music2,
  'music-4': LucideIcons.music4,
  'list-music': LucideIcons.listMusic,
  'audio-lines': LucideIcons.audioLines,
  'disc-3': LucideIcons.disc3,
  'drum': LucideIcons.drum,
  'drumstick': LucideIcons.drumstick,
  'guitar': LucideIcons.guitar,
  'piano': LucideIcons.piano,
  'mic': LucideIcons.mic,
  'mic-vocal': LucideIcons.micVocal,
  'headphones': LucideIcons.headphones,
  'radio': LucideIcons.radio,
  'speaker': LucideIcons.speaker,
  'church': LucideIcons.church,
  'hand-heart': LucideIcons.handHeart,
  'book-open': LucideIcons.bookOpen,
  'library': LucideIcons.library,
  'graduation-cap': LucideIcons.graduationCap,
  'users': LucideIcons.users,
  'baby': LucideIcons.baby,
  'party-popper': LucideIcons.partyPopper,
  'cake': LucideIcons.cake,
  'gift': LucideIcons.gift,
  'calendar': LucideIcons.calendar,
  'bell': LucideIcons.bell,
  'star': LucideIcons.star,
  'heart': LucideIcons.heart,
  'sparkles': LucideIcons.sparkles,
  'crown': LucideIcons.crown,
  'trophy': LucideIcons.trophy,
  'flame': LucideIcons.flame,
  'sun': LucideIcons.sun,
  'moon': LucideIcons.moon,
};

const _palette = [
  Color(0xff000000),
  Color(0xff2e1a6b),
  Color(0xff6d3bd2),
  Color(0xff8a5ce8),
  Color(0xffc9b6f5),
  Color(0xffe53935),
  Color(0xfffacc15),
  Color(0xff22a559),
  Color(0xff2196f3),
];

/// Icon color that stays readable on [background]: deep violet on light colors, white on dark.
Color iconOn(Color background) => background.computeLuminance() > .45
    ? const Color(0xff2e1a6b)
    : Colors.white;

IconData collectionIcon(String key) =>
    collectionIcons[key] ?? LucideIcons.music;

typedef CollectionDraft = ({
  String name,
  String icon,
  Color color,
  Color iconColor,
});

/// Bottom sheet that pops a [CollectionDraft], or null on cancel.
class CollectionEditor extends StatefulWidget {
  const CollectionEditor({
    super.key,
    required this.title,
    required this.action,
    this.name = '',
    this.icon = 'music',
    this.color = const Color(0xff6d3bd2),
  });
  final String title, action, name, icon;
  final Color color;
  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  late final name = TextEditingController(text: widget.name);
  final nameFocus = FocusNode();
  // Set when saving with a blank name; cleared as soon as one is typed.
  bool nameMissing = false;
  late var icon = widget.icon;
  late var color = widget.color;

  @override
  void dispose() {
    name.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  Widget _colors(String label, Color value, ValueChanged<Color> onPick) {
    final c = NotivoColors(context);
    Widget dot(Color? swatch) {
      final selected = swatch == null
          ? !_palette.contains(value)
          : swatch.toARGB32() == value.toARGB32();
      return Semantics(
        button: true,
        selected: selected,
        label: tr(context, swatch == null ? 'Escolher outra cor' : label),
        child: GestureDetector(
          onTap: () async {
            if (swatch != null) return onPick(swatch);
            FocusScope.of(context).unfocus();
            final picked = await showAppSheet<Color>(
              context,
              builder: (_) => ColorPickerSheet(initial: value),
            );
            if (picked != null && mounted) onPick(picked);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: swatch ?? (selected ? value : null),
              gradient: swatch == null && !selected
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
              border: Border.all(
                color: selected ? c.accent : c.line,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: swatch == null
                ? Icon(LucideIcons.plus, size: 16, color: c.tx)
                : null,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, label),
          style: designText(14, c.tx2, weight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final s in _palette) dot(s), dot(null)],
        ),
      ],
    );
  }

  void _save() {
    final text = name.text.trim();
    if (text.isEmpty) {
      setState(() => nameMissing = true);
      nameFocus.requestFocus();
      return;
    }
    Navigator.pop<CollectionDraft>(context, (
      name: text,
      icon: icon,
      color: color,
      iconColor: iconOn(color),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return AppSheet(
      // Live title: the typed name, or the default while it is blank.
      title: name.text.trim().isEmpty ? widget.title : name.text.trim(),
      leading: Semantics(
        label: tr(context, 'Pré-visualização'),
        child: Container(
          width: 56,
          height: 56,
          // The glyph always sits in the middle of the circle.
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: c.line),
          ),
          child: Icon(collectionIcon(icon), size: 26, color: iconOn(color)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancelar')),
        ),
        SheetPrimary(widget.action, onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: name,
            focusNode: nameFocus,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr(context, 'Nome'),
              errorText: nameMissing
                  ? tr(context, 'Dê um nome à coleção')
                  : null,
            ),
            onChanged: (value) => setState(() {
              if (value.trim().isNotEmpty) nameMissing = false;
            }),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'Ícone'),
            style: designText(14, c.tx2, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          // Tiles keep a similar size on phones and tablets.
          // Same tile size as a 64 px grid, but an incomplete last row stays centered.
          LayoutBuilder(
            builder: (context, bounds) {
              final perRow = ((bounds.maxWidth + 8) / 72).ceil();
              // The half pixel keeps rounding from pushing the last tile to a new row.
              final tile = (bounds.maxWidth - 8 * (perRow - 1)) / perRow - .5;
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in collectionIcons.entries)
                    SizedBox.square(
                      dimension: tile,
                      child: Semantics(
                        button: true,
                        selected: entry.key == icon,
                        label: entry.key,
                        child: Material(
                          color: entry.key == icon ? c.active : c.soft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: entry.key == icon
                                  ? c.accent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => icon = entry.key),
                            child: Icon(
                              entry.value,
                              size: 22,
                              color: entry.key == icon ? c.accent : c.tx,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _colors('Cor', color, (v) => setState(() => color = v)),
          const SizedBox(height: 6),
          Text(
            tr(context, 'A cor do ícone se ajusta sozinha para ficar legível.'),
            style: designText(12, c.tx2),
          ),
        ],
      ),
    );
  }
}
