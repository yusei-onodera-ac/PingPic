import 'package:flutter/material.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/public_feed/presentation/public_feed_screen.dart';

/// Two-tab shell: your group's feed, and the "みんなの投稿" public feed
/// (added this session — see docs/ARCHITECTURE.md "Resolved: public
/// posts / みんなの投稿"). Both tabs stay mounted via IndexedStack rather
/// than being torn down on switch — simpler than go_router's
/// StatefulShellRoute for just two tabs, at the cost of both screens'
/// Firestore listeners running simultaneously while this shell is up
/// (acceptable at this scale; a future optimization could pause the
/// inactive tab's streams).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [FeedScreen(), PublicFeedScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'グループ',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'みんな',
          ),
        ],
      ),
    );
  }
}
