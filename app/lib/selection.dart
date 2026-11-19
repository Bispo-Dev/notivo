import 'package:flutter/foundation.dart';

class ScoreSelection extends ValueNotifier<Set<int>> {
  ScoreSelection() : super(const <int>{});

  void toggle(int id) {
    final ids = {...value};
    if (!ids.add(id)) ids.remove(id);
    replace(ids);
  }

  void replace(Iterable<int> ids) => value = Set<int>.unmodifiable(ids);
  void clear() => value = const <int>{};
}
