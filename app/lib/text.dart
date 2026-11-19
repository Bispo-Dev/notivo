const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};

/// Lowercase and strip accents/cedilla, so "Ação" matches "acao".
String fold(String text) =>
    text.toLowerCase().split('').map((c) => _accents[c] ?? c).join();

final _chunks = RegExp(r'\d+|\D+');

/// Name order where digits compare as numbers: "Hino 2" before "Hino 10".
int naturalCompare(String a, String b) {
  final x = _chunks.allMatches(fold(a)).map((m) => m[0]!).toList();
  final y = _chunks.allMatches(fold(b)).map((m) => m[0]!).toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final nx = int.tryParse(x[i]), ny = int.tryParse(y[i]);
    final r = nx != null && ny != null ? nx.compareTo(ny) : x[i].compareTo(y[i]);
    if (r != 0) return r;
  }
  return x.length.compareTo(y.length);
}
