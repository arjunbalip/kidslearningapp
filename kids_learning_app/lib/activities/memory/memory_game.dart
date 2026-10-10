import 'dart:math' as math;

/// What happened after a card was tapped.
enum FlipResult {
  ignored, // already open, matched, or two cards are waiting to close
  first, // first card of a try
  match, // second card matches the first
  noMatch, // second card is different: call [MemoryGame.closeOpen] after a pause
}

/// What is on the two cards of a pair (letters; numbers always use [capital]).
enum CardFaces {
  capital, // A and A (or 3 and 3)
  small, // a and a
  mixed, // A and a: the picture is hidden, so the letter shape counts
}

/// One step of difficulty: how many pairs, and what the cards show.
class MemoryLevel {
  const MemoryLevel(this.pairs, {this.faces = CardFaces.capital});

  final int pairs;
  final CardFaces faces;

  /// Card counts the settings offer: 6, 8, 12 and 16 cards.
  static const pairChoices = [3, 4, 6, 8];
}

/// Rules of the Memory game, with no drawing.
///
/// [MemoryLevel.pairs] different items are each put on two cards,
/// shuffled, face down. The child opens two at a time; pairs stay open.
class MemoryGame {
  MemoryGame({required int itemCount, required this.level, math.Random? random})
      : _random = random ?? math.Random() {
    final picked = (List.generate(itemCount, (i) => i)..shuffle(_random))
        .take(math.min(level.pairs, itemCount))
        .toList();
    // Whether each card of a pair shows the small letter.
    final (firstSmall, secondSmall) = switch (level.faces) {
      CardFaces.capital => (false, false),
      CardFaces.small => (true, true),
      CardFaces.mixed => (false, true),
    };
    final deck = [
      for (final p in picked) ...[(p, firstSmall), (p, secondSmall)],
    ]..shuffle(_random);
    cards = [for (final c in deck) c.$1];
    small = {
      for (var i = 0; i < deck.length; i++)
        if (deck[i].$2) i
    };
  }

  /// Letters: same letter 3, 4, 6 pairs, then capital and small 4, 6 pairs.
  static const letterLevels = [
    MemoryLevel(3),
    MemoryLevel(4),
    MemoryLevel(6),
    MemoryLevel(4, faces: CardFaces.mixed),
    MemoryLevel(6, faces: CardFaces.mixed),
  ];

  /// Numbers: same number 3, 4, 6 pairs.
  static const numberLevels = [MemoryLevel(3), MemoryLevel(4), MemoryLevel(6)];

  final MemoryLevel level;
  final math.Random _random;

  /// Pack item index on each card, in grid order.
  late final List<int> cards;

  /// Cards that show the small letter.
  late final Set<int> small;

  /// Cards open but not yet matched (zero, one or two).
  final List<int> open = [];

  /// Cards that found their pair.
  final Set<int> matched = {};

  int get pairs => cards.length ~/ 2;
  int get pairsFound => matched.length ~/ 2;
  bool get done => matched.length == cards.length;

  bool isFaceUp(int card) => open.contains(card) || matched.contains(card);

  FlipResult flip(int card) {
    if (open.length >= 2 || isFaceUp(card)) return FlipResult.ignored;
    open.add(card);
    if (open.length == 1) return FlipResult.first;
    if (cards[open[0]] == cards[open[1]]) {
      matched.addAll(open);
      open.clear();
      return FlipResult.match;
    }
    return FlipResult.noMatch;
  }

  /// Turns the two different cards face down again.
  void closeOpen() => open.clear();
}
