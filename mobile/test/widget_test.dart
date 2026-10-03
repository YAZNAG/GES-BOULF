import 'package:flutter_test/flutter_test.dart';

import 'package:boulfrik/core/api.dart';
import 'package:boulfrik/core/format.dart';

void main() {
  test('lecture tolérante des nombres', () {
    final j = <String, dynamic>{'a': '4.50', 'b': 3, 'c': null, 'd': 'x'};
    expect(j.dbl('a'), 4.5);
    expect(j.integer('b'), 3);
    expect(j.dbl('c', 1), 1);
    expect(j.dblOrNull('d'), isNull);
  });

  test('saisie décimale', () {
    expect(parseInput('12,5'), 12.5);
    expect(parseInput(''), isNull);
    expect(round2(2.345 * 2), 4.69);
  });
}
