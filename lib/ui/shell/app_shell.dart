import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/forge_widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Permission.notification.request();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: widget.shell.currentIndex,
            onDestinationSelected: (index) {
              widget.shell.goBranch(index, initialLocation: index == widget.shell.currentIndex);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.smart_display_outlined),
                selectedIcon: Icon(Icons.smart_display),
                label: 'YouTube',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
