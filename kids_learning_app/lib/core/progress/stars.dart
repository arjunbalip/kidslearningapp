import 'package:flutter/foundation.dart';

/// Stars the child has earned.
///
/// Milestone 1 keeps them in memory only; saving them on the device
/// (shared_preferences) comes with the progress milestone.
class Stars {
  Stars._();

  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static void add([int amount = 1]) => count.value += amount;
}
