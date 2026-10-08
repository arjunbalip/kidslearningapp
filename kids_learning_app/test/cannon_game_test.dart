import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_learning_app/activities/cannon/cannon_game.dart';

void main() {
  test('each round is a run of items that follow each other', () {
    final g = CannonGame(itemCount: 10, random: math.Random(1));
    for (var r = 0; r < CannonGame.roundSizes.length; r++) {
      expect(g.order.length, CannonGame.roundSizes[r]);
      for (var i = 1; i < g.order.length; i++) {
        expect(g.order[i], g.order[i - 1] + 1);
      }
      expect(g.order.first, greaterThanOrEqualTo(0));
      expect(g.order.last, lessThan(10));
      while (!g.roundDone) {
        g.shoot(g.target!);
      }
      if (r < CannonGame.roundSizes.length - 1) g.nextRound();
    }
    expect(g.gameDone, isTrue);
  });

  test('only the next one in order pops', () {
    final g = CannonGame(itemCount: 26, random: math.Random(2));
    final first = g.order[0];
    final second = g.order[1];
    expect(g.shoot(second), isFalse);
    expect(g.popped, 0);
    expect(g.shoot(first), isTrue);
    expect(g.target, second);
  });

  test('a small pack still works', () {
    final g = CannonGame(itemCount: 2, random: math.Random(3));
    expect(g.order, [0, 1]);
  });
}
