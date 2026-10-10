import 'dart:math' as math;

/// What happened after a card was tapped.
enum FlipResult {
  ignored, // already open, matched, or two cards are waiting to close
  first, // first card of a try
  match, // second card matches the first
  noMatch, // second card is different: call [MemoryGame.closeOpen] after a pause
}

/// One step of difficulty: how many pairs, and whether a pair is a
/// capital and a small letter (A and a) instead of two the same.
class MemoryLevel {
  const MemoryLevel(this.pairs, {this.capitalAndSmall = false});

  final int pairs;
  final bool capitalAndSmall;
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
    // Each pair: one card as it is, one card small (only used for A and a).
    final deck = [
      for (final p in picked) ...[(p, false), (p, level.capitalAndSmall)],
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
    MemoryLevel(4, capitalAndSmall: true),
    MemoryLevel(6, capitalAndSmall: true),
  ];

  /// Numbers: same number 3, 4, 6 pairs.
  static const numberLevels = [MemoryLevel(3), MemoryLevel(4), MemoryLevel(6)];

  final MemoryLevel level;
  final math.Random _random;

  /// Pack item index on each card, in grid order.
  late final List<int> cards;

  /// Cards that show the small letter (capital-and-small levels only).
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
