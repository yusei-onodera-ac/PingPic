import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pulsing_placeholder.dart';
import '../../../shared/models/post_model.dart';
import '../../connections/data/connection_repository.dart';
import '../../prompts/data/daily_schedule_model.dart';

/// JST calendar-day id, matching the batch job's convention — see the
/// same helper in camera_screen.dart (kept duplicated rather than shared
/// to avoid a cross-feature import for one line; consider moving to
/// core/ if a third call site shows up).
String _todayDateIdJst() {
  final jstNow = DateTime.now().toUtc().add(const Duration(hours: 9));
  return '${jstNow.year.toString().padLeft(4, '0')}-'
      '${jstNow.month.toString().padLeft(2, '0')}-'
      '${jstNow.day.toString().padLeft(2, '0')}';
}

DateTime _todayMidnightDeadlineJst(String dateId) {
  return DateTime.parse('${dateId}T00:00:00+09:00').add(const Duration(days: 1));
}

PostModel? _postForSlot(List<PostModel> posts, int slotNumber) {
  for (final p in posts) {
    if (p.slotNumber == slotNumber) return p;
  }
  return null;
}

/// "フォロー中" — a TikTok-style full-screen vertical feed, one page per
/// connection; swipe up/down between people, swipe left/right within a
/// person's page to move between their 3 daily slots (Instagram-carousel
/// style), per this session's direction. A slot nobody's posted to yet
/// shows PulsingPlaceholder instead of a photo.
///
/// A mutual connection (see docs/ARCHITECTURE.md "Resolved: groups ->
/// mutual connections") sees ALL of the other person's posts regardless
/// of `isPublic` — that flag only controls whether a post ALSO appears
/// in "みんなの投稿" for people you're not connected to.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionRepo = ref.watch(connectionRepositoryProvider);
    final feedRepo = ref.watch(feedRepositoryProvider);
    final dateId = _todayDateIdJst();

    return StreamBuilder<List<ConnectionUser>>(
      stream: connectionRepo.watchConnections(),
      builder: (context, connectionsSnap) {
        if (connectionsSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.ink,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        final connections = connectionsSnap.data ?? const <ConnectionUser>[];
        if (connections.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('フォロー中')),
            // No action button here — HomeShell (the bottom-nav shell)
            // owns which tab is selected, and this screen doesn't have a
            // handle to it. Pointing at the tab by name is simpler than
            // plumbing a cross-tab-switch callback through for one CTA.
            body: const EmptyState(
              icon: Icons.person_add_alt_outlined,
              message: 'まだ友達がいません。\n下の「みんな」タブで気になる人に友達リクエストを送ってみましょう。',
            ),
          );
        }

        return StreamBuilder<DailyScheduleModel?>(
          stream: feedRepo.watchTodaySchedule(dateId),
          builder: (context, scheduleSnap) {
            final schedule = scheduleSnap.data;
            return Scaffold(
              backgroundColor: AppColors.ink,
              body: PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: connections.length,
                itemBuilder: (context, index) => _ConnectionPage(
                  user: connections[index],
                  dateId: dateId,
                  schedule: schedule,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConnectionPage extends ConsumerStatefulWidget {
  const _ConnectionPage({required this.user, required this.dateId, required this.schedule});

  final ConnectionUser user;
  final String dateId;
  final DailyScheduleModel? schedule;

  @override
  ConsumerState<_ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<_ConnectionPage> {
  final _pageController = PageController();
  int _slotIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(feedRepositoryProvider);

    return StreamBuilder<List<PostModel>>(
      stream: repo.watchUserPosts(widget.user.uid, widget.dateId),
      builder: (context, postsSnap) {
        final posts = postsSnap.data ?? const <PostModel>[];

        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: 3,
              onPageChanged: (i) => setState(() => _slotIndex = i),
              itemBuilder: (context, slotIdx) {
                final slotNumber = slotIdx + 1;
                final post = _postForSlot(posts, slotNumber);
                if (post == null) {
                  return const PulsingPlaceholder();
                }
                return Image.network(
                  post.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const PulsingPlaceholder(
                    label: '読み込みに失敗しました',
                  ),
                );
              },
            ),
            _PageDots(count: 3, index: _slotIndex),
            _ConnectionOverlay(
              user: widget.user,
              slotNumber: _slotIndex + 1,
              dateId: widget.dateId,
              promptText: widget.schedule?.slots.length == 3
                  ? widget.schedule!.slots[_slotIndex]?.promptText
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: List.generate(count, (i) {
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == index ? Colors.white : Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ConnectionOverlay extends StatelessWidget {
  const _ConnectionOverlay({
    required this.user,
    required this.slotNumber,
    required this.dateId,
    required this.promptText,
  });

  final ConnectionUser user;
  final int slotNumber;
  final String dateId;
  final String? promptText;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 40, 16, MediaQuery.of(context).padding.bottom + 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push(
                    '${AppRoutes.profile}/${user.uid}?name=${Uri.encodeComponent(user.displayName)}',
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.coral,
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName.substring(0, 1) : '?',
                          style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        user.displayName,
                        style: AppTextStyles.bodyStrong.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (slotNumber == 3)
                  CountdownText(
                    deadline: _todayMidnightDeadlineJst(dateId),
                    style: AppTextStyles.caption.copyWith(color: AppColors.coral),
                  ),
              ],
            ),
            if (promptText != null) ...[
              const SizedBox(height: 8),
              Text(
                promptText!,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
