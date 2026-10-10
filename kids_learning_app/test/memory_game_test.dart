import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_learning_app/activities/memory/memory_game.dart';

void main() {
  test('every item is on exactly two cards', () {
    for (final pairs in MemoryGame.levelPairs) {
      final g = MemoryGame(itemCount: 26, pairs: pairs, random: math.Random(pairs));
      expect(g.cards.length, pairs * 2);
      final counts = <int, int>{};
      for (final c in g.cards) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      expect(counts.length, pairs);
      expect(counts.values.every((n) => n == 2), isTrue);
    }
  });

  test('matching pairs stay open, others close again', () {
    final g = MemoryGame(itemCount: 26, pairs: 3, random: math.Random(7));
    const first = 0;
    final same = g.cards.lastIndexOf(g.cards[first]);
    final other = g.cards.indexWhere((c) => c != g.cards[first]);

    expect(g.flip(first), FlipResult.first);
    expect(g.flip(other), FlipResult.noMatch);
    expect(g.flip(same), FlipResult.ignored, reason: 'two cards are waiting to close');
    g.closeOpen();
    expect(g.isFaceUp(first), isFalse);

    expect(g.flip(first), FlipResult.first);
    expect(g.flip(first), FlipResult.ignored, reason: 'same card twice');
    expect(g.flip(same), FlipResult.match);
    expect(g.isFaceUp(first), isTrue);
    expect(g.pairsFound, 1);
  });

  test('finding every pair finishes the game', () {
    final g = MemoryGame(itemCount: 10, pairs: 4, random: math.Random(3));
    for (var i = 0; i < g.cards.length; i++) {
      if (g.isFaceUp(i)) continue;
      g.flip(i);
      g.flip(g.cards.lastIndexOf(g.cards[i]) == i ? g.cards.indexOf(g.cards[i]) : g.cards.lastIndexOf(g.cards[i]));
    }
    expect(g.done, isTrue);
  });
}
