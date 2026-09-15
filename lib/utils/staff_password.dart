import 'dart:math';

/// A pronounceable six-letter stem, four digits and one familiar symbol.
/// Only the first letter is capitalized; randomness comes from the OS.
String generateStaffPassword() {
  final random = Random.secure();
  const consonants = 'bcdfghjklmnprstvwz';
  const vowels = 'aeiou';
  const symbols = '#!@_()&';
  final stem = List.generate(
    3,
    (_) =>
        consonants[random.nextInt(consonants.length)] +
        vowels[random.nextInt(vowels.length)],
  ).join();
  return stem[0].toUpperCase() +
      stem.substring(1) +
      List.generate(4, (_) => random.nextInt(10)).join() +
      symbols[random.nextInt(symbols.length)];
}
