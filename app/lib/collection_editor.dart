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
  'cross': LucideIcons.cross,
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

/// Columns of the icon grid.
const collectionIconColumns = 6;

const _palette = [
  Colors.white,
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
    this.name = '',
    this.icon = 'music',
    this.color = const Color(0xff6d3bd2),
    this.iconColor = Colors.white,
  });
  final String title, name, icon;
  final Color color, iconColor;
  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  late final name = TextEditingController(text: widget.name);
  late var icon = widget.icon;
  late var color = widget.color;
  late var iconColor = widget.iconColor;

  @override
  void dispose() {
    name.dispose();
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
    if (text.isEmpty) return;
    Navigator.pop<CollectionDraft>(context, (
      name: text,
      icon: icon,
      color: color,
      iconColor: iconColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = NotivoColors(context);
    return AppSheet(
      title: widget.title,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancelar')),
        ),
        FilledButton(onPressed: _save, child: Text(tr(context, 'Concluir'))),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Semantics(
              label: tr(context, 'Pré-visualização'),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line),
                ),
                child: Icon(collectionIcon(icon), size: 32, color: iconColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr(context, 'Nome')),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'Ícone'),
            style: designText(14, c.tx2, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: collectionIconColumns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final entry in collectionIcons.entries)
                Semantics(
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
            ],
          ),
          const SizedBox(height: 20),
          _colors(
            'Cor do ícone',
            iconColor,
            (v) => setState(() => iconColor = v),
          ),
          const SizedBox(height: 20),
          _colors('Cor de fundo', color, (v) => setState(() => color = v)),
        ],
      ),
    );
  }
}
