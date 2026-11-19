import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const notivoLocalizationDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const notivoSupportedLocales = <Locale>[Locale('pt'), Locale('en')];

const _englishStrings = <String, String>{
  // Library and collection management.
  'Nova coleção': 'New collection',
  'Suas partituras, sempre à mão.': 'Your scores, always at hand.',
  'Nenhuma coleção ainda': 'No collections yet',
  'Crie uma coleção para organizar suas partituras.':
      'Create a collection to organize your scores.',
  'Ver partituras': 'Browse scores',
  'Ações da coleção': 'Collection actions',
  'partituras': 'scores',
  'partitura': 'score',
  'selecionadas': 'selected',
  'sel.': 'sel.',
  'Renomear': 'Rename',
  'Limpar': 'Clear',
  'Abrir em abas': 'Open in tabs',

  // Score lists and navigation.
  'Selecionar partituras': 'Select scores',
  'Buscar partituras': 'Search scores',
  'Segure uma partitura para selecionar, mesmo de coleções diferentes.':
      'Press and hold a score to select scores from different collections.',
  'Nenhuma partitura nesta coleção.': 'No scores in this collection.',
  'Nenhuma partitura importada.': 'No scores imported yet.',
  'Nenhuma partitura importada. Importe um PDF para começar.':
      'No scores imported yet. Import a PDF to get started.',
  'Sem coleção': 'No collection',
  'Música': 'Music',
  'Banda': 'Band',
  'Igreja': 'Church',
  'Estudos': 'Studies',
  'Nome': 'Name',
  'Nome no Notivo': 'Name in Notivo',
  'Organizar': 'Organize',
  'Voltar': 'Back',
  'Importar PDFs': 'Import PDFs',
  'Início': 'Home',
  'Abrir partitura': 'Open score',
  'Abrir outra partitura': 'Open another score',
  'Fechar aba': 'Close tab',
  'Recolher abas': 'Collapse tabs',
  'Mostrar abas e ferramentas': 'Show tabs and tools',
  'Mostrar ferramentas': 'Show tools',

  // Drawing and export controls.
  'Caneta': 'Pen',
  'Grifador': 'Highlighter',
  'Borracha': 'Eraser',
  'Navegar': 'Navigate',
  'Desfazer': 'Undo',
  'Exportar PDF': 'Export PDF',
  'Recolher ferramentas': 'Collapse tools',
  'Escolher outra cor': 'Choose another color',
  'Cor de anotação': 'Annotation color',
  'Cor personalizada (RGB)': 'Custom color (RGB)',
  'Cor da anotação': 'Annotation color',

  // Color picker.
  'Campo de saturação e brilho': 'Saturation and brightness field',
  'Matiz': 'Hue',
  'Faixa de matiz': 'Hue slider',
  'RGB': 'RGB',
  'Saturação e brilho': 'Saturation and brightness',
  'Usar cor': 'Use color',

  // Shared dialog and feedback strings from main.dart.
  'Cancelar': 'Cancel',
  'Concluir': 'Done',
  'Editar coleção': 'Edit collection',
  'Remover coleção': 'Delete collection',
  'Remover coleção?': 'Delete collection?',
  'Escolher cor': 'Choose color',
  'Ícone': 'Icon',
  'Ícone da coleção': 'Collection icon',
  'Coleções': 'Collections',
  'Adicionar partituras': 'Add scores',
  'Renomear partitura': 'Rename score',
  'Manter pressionado para alternar tema': 'Long press to switch theme',
  'Não foi possível abrir a biblioteca.': 'Could not open the library.',
  'Não foi possível abrir as partituras.': 'Could not open the scores.',
  'Não foi possível importar': 'Could not import',
  'Não foi possível remover a coleção': 'Could not delete the collection',
  'Falha ao exportar': 'Export failed',
  'As partituras e anotações serão mantidas.':
      'Scores and annotations will be kept.',
  'Falha ao salvar anotações': 'Failed to save annotations',
  'Falha ao carregar anotações': 'Failed to load annotations',
  'Recolher abas e ferramentas': 'Collapse tabs and tools',

  // Collection editor, selection and lock.
  'Selecionar': 'Select',
  'Ações da partitura': 'Score actions',
  'Remover': 'Remove',
  'Ordenar': 'Sort',
  'Mais recentes': 'Most recent',
  'Nome / número crescente': 'Name / number ascending',
  'Nome / número decrescente': 'Name / number descending',
  'Menos recentes': 'Oldest',
  'Remover da coleção': 'Remove from collection',
  'Não foi possível renomear': 'Could not rename',
  'Não foi possível salvar': 'Could not save',
  'Não foi possível remover': 'Could not remove',
  'Não foi possível salvar a coleção': 'Could not save the collection',
  'Cor do ícone': 'Icon color',
  'Cor de fundo': 'Background color',
  'Pré-visualização': 'Preview',
  'Partituras bloqueadas': 'Scores locked',
  'Deseja sair mesmo assim?': 'Leave anyway?',
  'Sair': 'Leave',
  'Bloquear partituras': 'Lock scores',
  'Desbloquear partituras': 'Unlock scores',

  // Import, undo, selection actions and reader options.
  'Importar para': 'Import into',
  'partitura importada': 'score imported',
  'partituras importadas': 'scores imported',
  'Partitura fechada': 'Score closed',
  'Partitura removida da coleção': 'Score removed from collection',
  'Partituras removidas da coleção': 'Scores removed from collection',
  'Não foi possível desfazer': 'Could not undo',
  'Adicionar à coleção': 'Add to collection',
  'Refazer': 'Redo',
  'Espessura do traço': 'Stroke thickness',
  'Mais opções': 'More options',
  'Desenhar só com caneta stylus': 'Draw with stylus only',
  'O toque do dedo e da mão não risca a partitura.':
      "Finger and palm touches won't draw on the score.",

  // Settings.
  'Menu': 'Menu',
  'Aparência': 'Appearance',
  'Modo escuro': 'Dark mode',
  'Idioma': 'Language',
  'Português': 'Português',
  'English': 'English',
};

/// Returns the English equivalent when the active locale is English.
/// Portuguese is the source language and remains the fallback for other locales.
String tr(BuildContext context, String text) {
  final languageCode = Localizations.localeOf(context).languageCode;
  if (!languageCode.toLowerCase().startsWith('en')) return text;
  return _englishStrings[text] ?? text;
}
