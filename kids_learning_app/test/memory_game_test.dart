import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_learning_app/activities/memory/memory_game.dart';

void main() {
  test('every item is on exactly two cards', () {
    for (final level in [
      ...MemoryGame.letterLevels,
      ...MemoryGame.numberLevels
    ]) {
      final pairs = level.pairs;
      final g =
          MemoryGame(itemCount: 26, level: level, random: math.Random(pairs));
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
    final g = MemoryGame(
        itemCount: 26, level: const MemoryLevel(3), random: math.Random(7));
    const first = 0;
    final same = g.cards.lastIndexOf(g.cards[first]);
    final other = g.cards.indexWhere((c) => c != g.cards[first]);

    expect(g.flip(first), FlipResult.first);
    expect(g.flip(other), FlipResult.noMatch);
    expect(g.flip(same), FlipResult.ignored,
        reason: 'two cards are waiting to close');
    g.closeOpen();
    expect(g.isFaceUp(first), isFalse);

    expect(g.flip(first), FlipResult.first);
    expect(g.flip(first), FlipResult.ignored, reason: 'same card twice');
    expect(g.flip(same), FlipResult.match);
    expect(g.isFaceUp(first), isTrue);
    expect(g.pairsFound, 1);
  });

  test('finding every pair finishes the game', () {
    final g = MemoryGame(
        itemCount: 10, level: const MemoryLevel(4), random: math.Random(3));
    for (var i = 0; i < g.cards.length; i++) {
      if (g.isFaceUp(i)) continue;
      g.flip(i);
      g.flip(g.cards.lastIndexOf(g.cards[i]) == i
          ? g.cards.indexOf(g.cards[i])
          : g.cards.lastIndexOf(g.cards[i]));
    }
    expect(g.done, isTrue);
  });

  test('capital-and-small levels pair one capital with one small card', () {
    final g = MemoryGame(
        itemCount: 26,
        level: const MemoryLevel(4, faces: CardFaces.mixed),
        random: math.Random(5));
    expect(g.small.length, 4);
    for (var i = 0; i < g.cards.length; i++) {
      final partner = [
        for (var j = 0; j < g.cards.length; j++)
          if (j != i && g.cards[j] == g.cards[i]) j
      ].single;
      expect(g.small.contains(i), isNot(g.small.contains(partner)));
    }
  });

  test('same-letter levels have no small cards', () {
    final g = MemoryGame(
        itemCount: 26, level: const MemoryLevel(6), random: math.Random(6));
    expect(g.small, isEmpty);
  });

  test('small-letter pairs show the small letter on both cards', () {
    final g = MemoryGame(
        itemCount: 26,
        level: const MemoryLevel(8, faces: CardFaces.small),
        random: math.Random(8));
    expect(g.cards.length, 16);
    expect(g.small.length, 16);
  });
}
