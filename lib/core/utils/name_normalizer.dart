/// Simple, deliberately dumb normalization so obvious duplicates (casing,
/// spacing, a trailing "bus"/"বাস") collapse onto the same community.
/// Not NLP — just enough to reduce accidental fragmentation for the MVP.
class NameNormalizer {
  NameNormalizer._();

  static const _trailingWords = ['bus', 'বাস'];

  static String normalize(String input) {
    var value = input.trim().toLowerCase();
    value = value.replaceAll(RegExp(r'\s+'), ' ');

    for (final word in _trailingWords) {
      final suffix = ' $word';
      if (value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length).trim();
      }
    }

    // Drop punctuation that doesn't change identity.
    value = value.replaceAll(RegExp(r'[.,!?]'), '');

    return value;
  }
}
