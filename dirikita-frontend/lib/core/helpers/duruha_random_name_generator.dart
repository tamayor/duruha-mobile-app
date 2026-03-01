import 'dart:math';

class DuruhaRandomNameGenerator {
  static final List<String> _adjectives = [
    'Fast',
    'Wise',
    'Bold',
    'Cool',
    'Kind',
    'Calm',
    'Brave',
    'Sunny',
    'Wild',
    'Deep',
    'Grey',
    'Blue',
    'Red',
    'Fresh',
    'Pure',
    'Soft',
    'Sharp',
    'Grand',
    'Smart',
    'Fair',
    'Loyal',
    'Great',
    'Quiet',
    'Proud',
    'Fancy',
    'Happy',
    'Swift',
    'Light',
    'Solid',
    'Vast',
    'Lucky',
    'Bright',
    'Chilly',
    'Crisp',
    'Noble',
    'Super',
    'Elite',
    'Agile',
    'Vibrant',
    'Prime',
    'Eager',
    'Fierce',
    'Gentle',
    'Hardy',
    'Jolly',
    'Mighty',
    'Plucky',
    'Stable',
    'Valiant',
    'Zen',
  ];

  static final List<String> _nouns = [
    'Bear',
    'Wolf',
    'Deer',
    'Lion',
    'Bird',
    'Tree',
    'Leaf',
    'Rain',
    'Wind',
    'Fire',
    'Moon',
    'Star',
    'Hill',
    'Lake',
    'Road',
    'Farm',
    'Seed',
    'Root',
    'Peak',
    'Cave',
    'Wave',
    'Bolt',
    'Zone',
    'Path',
    'Park',
    'Home',
    'Song',
    'Bell',
    'Ship',
    'Fort',
    'Stone',
    'Rock',
    'Cloud',
    'Field',
    'Ocean',
    'Brook',
    'Glade',
    'Mist',
    'Ridge',
    'Coast',
    'Eagle',
    'Hawk',
    'Falcon',
    'Owl',
    'Panda',
    'Otter',
    'Badger',
    'Fox',
    'Tiger',
    'Lynx',
  ];

  /// Generates a name like "Wise-Bear" or "Brave-Gold-Star"
  static String generate({
    int wordCount = 2,
    String separator = '-',
    String? idSeed,
  }) {
    int? numericSeed;
    if (idSeed != null) {
      // Create a better hash that prevents similar UUID prefixes from causing collisions.
      int hash = 5381;
      for (int i = 0; i < idSeed.length; i++) {
        hash = ((hash << 5) + hash) + idSeed.codeUnitAt(i);
      }
      numericSeed = hash;
    }
    final random = numericSeed != null ? Random(numericSeed) : Random();
    List<String> selectedParts = [];

    // Add 1 or 2 adjectives
    for (int i = 0; i < wordCount - 1; i++) {
      selectedParts.add(_adjectives[random.nextInt(_adjectives.length)]);
    }

    // Always end with a noun
    selectedParts.add(_nouns[random.nextInt(_nouns.length)]);

    return selectedParts.join(separator);
  }
}
