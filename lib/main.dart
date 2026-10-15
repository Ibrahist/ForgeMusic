import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/db/app_database.dart';
import 'data/library_bus.dart';
import 'data/services/artwork_store.dart';
import 'data/services/download_manager.dart';
import 'data/services/media_resolver.dart';
import 'data/services/youtube_service.dart';
import 'data/settings_store.dart';
import 'player/forge_audio_handler.dart';
import 'state/providers.dart';
import 'ui/router.dart';
import 'ui/theme/forge_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final bus = LibraryBus();
  final settings = await SettingsStore().load();
  final artwork = ArtworkStore();
  final youtube = YoutubeService();
  final downloads = DownloadManager(database, youtube);
  final resolver = MediaResolver(database, youtube, downloads);
  final player = await AudioService.init(
    builder: () => ForgeAudioHandler(
      database: database,
      bus: bus,
      resolver: resolver,
      downloads: downloads,
      settings: settings,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.forgemusic.player.audio',
      androidNotificationChannelName: 'Forgemusic',
      androidNotificationChannelDescription: 'Playback controls',
      androidNotificationIcon: 'drawable/ic_notification',
      androidStopForegroundOnPause: false,
      notificationColor: Color(0xFFE8884E),
    ),
  );
  await player.prepare();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        libraryBusProvider.overrideWithValue(bus),
        initialSettingsProvider.overrideWithValue(settings),
        artworkProvider.overrideWithValue(artwork),
        youtubeProvider.overrideWithValue(youtube),
        downloadsProvider.overrideWithValue(downloads),
        resolverProvider.overrideWithValue(resolver),
        playerProvider.overrideWithValue(player),
      ],
      child: const ForgemusicApp(),
    ),
  );
}

class ForgemusicApp extends ConsumerWidget {
  const ForgemusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accent = settings.dynamicColor ? ref.watch(accentProvider) : ForgeColors.ember;
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Forgemusic',
      debugShowCheckedModeBanner: false,
      theme: forgeTheme(Brightness.light, accent),
      darkTheme: forgeTheme(Brightness.dark, accent),
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return AnimatedTheme(
          duration: const Duration(milliseconds: 450),
          data: Theme.of(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter());
