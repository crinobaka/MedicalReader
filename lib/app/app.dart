import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_page.dart';
import '../features/library/pages/library_page.dart';
import '../features/library/providers/library_provider.dart';
import '../features/reader/providers/reader_view_options_provider.dart';
import '../features/reader/services/reader_ui_theme.dart';
import '../features/search/search_page.dart';
import '../features/settings/pages/settings_page.dart';

class MedicalReaderApp extends ConsumerWidget {
  const MedicalReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(readerViewOptionsProvider);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final readerTheme =
        ReaderUiTheme.resolve(options.themePreset, platformBrightness);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedicalReader',
      theme: readerTheme.themeData(brightness: Brightness.light),
      darkTheme: ReaderUiTheme.resolve(
        options.themePreset,
        Brightness.dark,
      ).themeData(brightness: Brightness.dark),
      themeMode: options.nightMode ? ThemeMode.dark : ThemeMode.system,
      home: const MainShell(),
    );
  }
}

/// 自适应主导航：手机优先使用底部导航，大屏使用左侧 NavigationRail。
/// “知识”能力保留在首页工作台，一级导航保持四项主入口。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int index = 0;

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: '首页',
    ),
    NavigationDestination(
      icon: Icon(Icons.library_books_outlined),
      selectedIcon: Icon(Icons.library_books),
      label: '书库',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: '搜索',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '设置',
    ),
  ];

  static const railDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('首页'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.library_books_outlined),
      selectedIcon: Icon(Icons.library_books),
      label: Text('书库'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: Text('搜索'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('设置'),
    ),
  ];

  final pages = const <Widget>[
    HomePage(),
    LibraryPage(),
    SearchPage(),
    SettingsPage(),
  ];

  void _select(int value) {
    if (value == index) return;
    setState(() => index = value);
    if (value == 1) {
      ref.invalidate(libraryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final body = pages[index];

        if (!useRail) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: _select,
              destinations: destinations,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: _select,
                extended: constraints.maxWidth >= 1100,
                labelType: constraints.maxWidth >= 1100
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                groupAlignment: -0.75,
                destinations: railDestinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
