import 'package:go_router/go_router.dart';

import '../activities/learn_cards/letter_cards_screen.dart';
import '../activities/learn_cards/number_cards_screen.dart';
import '../activities/tracing/trace_screen.dart';
import '../activities/tracing/trace_shape.dart';
import '../features/home/home_screen.dart';
import '../features/parent/parent_access.dart';
import '../features/parent/parent_gate_screen.dart';
import '../features/parent/packs_screen.dart';
import '../features/reward/reward_screen.dart';
import '../features/world/world_screen.dart';

int _index(GoRouterState state) =>
    int.tryParse(state.pathParameters['index'] ?? '') ?? 0;

/// All screens of the app. Routes match the Technical Design.
final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'letters',
          builder: (context, state) =>
              const WorldScreen(kind: WorldKind.letters),
          routes: [
            GoRoute(
              path: 'learn/:index',
              builder: (context, state) =>
                  LetterCardsScreen(initialIndex: _index(state)),
            ),
            GoRoute(
              path: 'trace/:index',
              builder: (context, state) => TraceScreen(
                kind: TraceKind.upper,
                initialIndex: _index(state),
              ),
            ),
            GoRoute(
              path: 'trace-small/:index',
              builder: (context, state) => TraceScreen(
                kind: TraceKind.lower,
                initialIndex: _index(state),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'numbers',
          builder: (context, state) =>
              const WorldScreen(kind: WorldKind.numbers),
          routes: [
            GoRoute(
              path: 'learn/:index',
              builder: (context, state) =>
                  NumberCardsScreen(initialIndex: _index(state)),
            ),
            GoRoute(
              path: 'trace/:index',
              builder: (context, state) => TraceScreen(
                kind: TraceKind.number,
                initialIndex: _index(state),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'reward',
          builder: (context, state) =>
              RewardScreen(next: state.extra as String? ?? '/'),
        ),
        GoRoute(
          path: 'parent/gate',
          builder: (context, state) => const ParentGateScreen(),
        ),
        GoRoute(
          path: 'parent/packs',
          // The parent area is only reachable through the gate.
          redirect: (context, state) =>
              ParentAccess.isOpen ? null : '/parent/gate',
          builder: (context, state) => const PacksScreen(),
        ),
      ],
    ),
  ],
);
