import 'package:go_router/go_router.dart';
import '../screens/main_screen.dart';
import '../screens/create_card_screen.dart';
import '../screens/edit_card_screen.dart';
import '../screens/settings_screen.dart';

/// App router configuration
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/create',
      name: 'create',
      builder: (context, state) => const CreateCardScreen(),
    ),
    GoRoute(
      path: '/edit/:cardId',
      name: 'edit',
      builder: (context, state) {
        final cardId = state.pathParameters['cardId']!;
        return EditCardScreen(cardId: cardId);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
