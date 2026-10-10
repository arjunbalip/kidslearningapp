import 'dart:math' as math;

/// What happened after a card was tapped.
enum FlipResult {
  ignored, // already open, matched, or two cards are waiting to close
  first, // first card of a try
  match, // second card matches the first
  noMatch, // second card is different: call [MemoryGame.closeOpen] after a pause
}

/// Rules of the Memory game, with no drawing.
///
/// [pairs] different items are each put on two cards, shuffled, face down.
/// The child opens two at a time; matching pairs stay open.
class MemoryGame {
  MemoryGame({required int itemCount, required int pairs, math.Random? random})
      : _random = random ?? math.Random() {
    final picked = (List.generate(itemCount, (i) => i)..shuffle(_random))
        .take(math.min(pairs, itemCount))
        .toList();
    cards = ([...picked, ...picked]..shuffle(_random));
  }

  /// Pairs per level: easy first, then harder after each win.
  static const levelPairs = [3, 4, 6];

  final math.Random _random;

  /// Pack item index on each card, in grid order.
  late final List<int> cards;

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
