import 'dart:math' as math;

/// Rules of the Balloon Cannon game, with no drawing: which items each
/// round uses, and which balloon must be shot next.
///
/// A game is [roundSizes].length rounds. Each round takes a run of items
/// that follow each other in the pack (2 3 4, or D E F G), and the child
/// shoots them in order.
class CannonGame {
  CannonGame({required this.itemCount, math.Random? random})
      : _random = random ?? math.Random() {
    _startRound();
  }

  /// Balloons per round: easy first, a little harder at the end.
  static const roundSizes = [3, 3, 4, 4, 5];

  final int itemCount;
  final math.Random _random;

  int round = 0;

  /// Pack item indexes of this round, in the order they must be shot.
  List<int> order = const [];

  /// How many of [order] have been popped.
  int popped = 0;

  bool get roundDone => popped >= order.length;
  bool get gameDone => round >= roundSizes.length - 1 && roundDone;

  /// The pack item index the cannon wants next, or null when the round is done.
  int? get target => roundDone ? null : order[popped];

  /// Returns true (and moves on) when [itemIndex] is the next one in order.
  bool shoot(int itemIndex) {
    if (itemIndex != target) return false;
    popped++;
    return true;
  }

  /// Starts the next round. Call after [roundDone].
  void nextRound() {
    if (round < roundSizes.length - 1) round++;
    _startRound();
  }

  void _startRound() {
    final size = math.min(roundSizes[round], itemCount);
    final start = _random.nextInt(itemCount - size + 1);
    order = [for (var i = 0; i < size; i++) start + i];
    popped = 0;
  }
}
