import 'package:flutter_test/flutter_test.dart';
import 'package:notivo/text.dart';

void main() {
  test('fold ignores case, accents and cedilla', () {
    expect(fold('AÇÃO Ênfase Órgão'), 'acao enfase orgao');
    expect(fold('Coração').contains(fold('CORACAO')), isTrue);
  });

  test('naturalCompare orders numbers by value', () {
    final names = ['Hino 10', 'hino 2', 'Ária', 'Hino 1', 'Abertura', '3 Coral'];
    names.sort(naturalCompare);
    expect(names, ['3 Coral', 'Abertura', 'Ária', 'Hino 1', 'hino 2', 'Hino 10']);
  });
}
