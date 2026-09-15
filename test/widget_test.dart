import 'package:flutter_test/flutter_test.dart';

import 'package:bus_koi/core/utils/name_normalizer.dart';

void main() {
  group('NameNormalizer', () {
    test('collapses casing and whitespace differences', () {
      expect(NameNormalizer.normalize('Bahon'), NameNormalizer.normalize('  bahon  '));
      expect(NameNormalizer.normalize('BAHON'), 'bahon');
    });

    test('collapses a trailing "bus"/"বাস" so "Bahon" and "Bahon Bus" match', () {
      expect(NameNormalizer.normalize('Bahon Bus'), NameNormalizer.normalize('Bahon'));
      expect(NameNormalizer.normalize('বাহন বাস'), NameNormalizer.normalize('বাহন'));
    });

    test('strips trailing punctuation', () {
      expect(NameNormalizer.normalize('Bahon!'), 'bahon');
    });
  });
}
