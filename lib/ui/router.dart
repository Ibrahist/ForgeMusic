import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shelf_screen.dart';
import 'screens/tag_screen.dart';
import 'screens/video_screen.dart';
import 'screens/youtube_screen.dart';
import 'shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'album/:key',
                    builder: (context, state) => ShelfScreen(kind: ShelfKind.album, id: state.pathParameters['key']!),
                  ),
                  GoRoute(
                    path: 'artist/:key',
                    builder: (context, state) => ShelfScreen(kind: ShelfKind.artist, id: state.pathParameters['key']!),
                  ),
                  GoRoute(
                    path: 'genre/:key',
                    builder: (context, state) => ShelfScreen(kind: ShelfKind.genre, id: state.pathParameters['key']!),
                  ),
                  GoRoute(
                    path: 'folder/:key',
                    builder: (context, state) => ShelfScreen(kind: ShelfKind.folder, id: state.pathParameters['key']!),
                  ),
                  GoRoute(
                    path: 'playlist/:id',
                    builder: (context, state) => ShelfScreen(kind: ShelfKind.playlist, id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/youtube', builder: (context, state) => const YoutubeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PlayerScreen(),
      ),
      GoRoute(
        path: '/video',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const VideoScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/tags/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => TagScreen(trackId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/queue',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const QueueScreen(),
      ),
    ],
  );
}
