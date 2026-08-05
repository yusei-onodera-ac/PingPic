import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../prompts/data/daily_schedule_model.dart';
import '../../../shared/models/group_model.dart';
import '../../../shared/models/post_model.dart';

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

/// Shows today's 3 prompt slots as a group feed: per the design doc's
/// retention mechanic, a slot's photos (yours and groupmates') only
/// become visible once YOU'VE posted your own for that slot — until then
/// it just shows a count of who's already posted and a shoot button.
///
/// Gates on group membership itself (rather than a router redirect — see
/// app_router.dart's comment on why): a user with no group yet sees a
/// join/create prompt instead of the slot list.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupRepo = ref.watch(groupRepositoryProvider);

    return StreamBuilder<GroupModel?>(
      stream: groupRepo.watchMyGroup(),
      builder: (context, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final group = groupSnap.data;
        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('PingPic')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('まだグループに参加していません'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.groupSetup),
                      child: const Text('グループに参加 / 作成する'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return _FeedBody(group: group);
      },
    );
  }
}

Future<void> _confirmLeaveGroup(BuildContext context, WidgetRef ref, GroupModel group) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('グループを退出しますか？'),
      content: Text(
        '「${group.name}」を退出します。これまでの投稿は残りますが、このグループのフィードは見られなくなります。',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出する')),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(groupRepositoryProvider).leaveGroup(group.id);
  // No explicit navigation needed — FeedScreen's watchMyGroup() stream
  // (built on the groups collection's memberIds) emits null once the
  // leave takes effect, and its own build() already shows the
  // join/create prompt for that case.
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateId = _todayDateIdJst();
    final repo = ref.watch(feedRepositoryProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'お題を提案する',
            onPressed: () => context.push(AppRoutes.suggest),
          ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('グループを退出'),
                onTap: () => _confirmLeaveGroup(context, ref, group),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DailyScheduleModel?>(
        stream: repo.watchTodaySchedule(dateId),
        builder: (context, scheduleSnap) {
          if (scheduleSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final schedule = scheduleSnap.data;
          if (schedule == null) {
            return const Center(child: Text('本日のお題はまだ設定されていません'));
          }
          return StreamBuilder<List<PostModel>>(
            stream: repo.watchGroupPosts(group.id, dateId),
            builder: (context, postsSnap) {
              final allPosts = postsSnap.data ?? const <PostModel>[];
              return ListView.builder(
                itemCount: schedule.slots.length,
                itemBuilder: (context, index) {
                  final slotNumber = index + 1;
                  final slotPosts =
                      allPosts.where((p) => p.slotNumber == slotNumber).toList(growable: false);
                  return _SlotCard(
                    slotNumber: slotNumber,
                    slot: schedule.slots[index],
                    slotPosts: slotPosts,
                    myUid: myUid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slotNumber,
    required this.slot,
    required this.slotPosts,
    required this.myUid,
  });

  final int slotNumber;
  final ScheduleSlot? slot;
  final List<PostModel> slotPosts;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    if (slot == null) {
      return ListTile(
        title: Text('スロット$slotNumber'),
        subtitle: const Text('まだお題が設定されていません'),
      );
    }

    final myPosts = slotPosts.where((p) => p.userId == myUid).toList(growable: false);
    final hasPosted = myPosts.isNotEmpty;
    final othersPosts = slotPosts.where((p) => p.userId != myUid).toList(growable: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasPosted ? Icons.check_circle : Icons.circle_outlined,
                  color: hasPosted ? Colors.green : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(slot!.promptText, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            Text(
              slot!.credit.when(
                admin: () => '運営考案',
                user: (_, displayName) => '$displayNameさん考案',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!hasPosted) ...[
              // Deliberately no thumbnails, not even blurred ones — per
              // the design doc's mechanic, groupmates' photos for this
              // slot stay hidden entirely until you post your own. Just
              // showing a count keeps that boundary honest (a blurred
              // <img> would still mean the photo bytes were fetched).
              Text(
                othersPosts.isEmpty
                    ? 'まだ誰も投稿していません'
                    : '${othersPosts.length}人が投稿済み — あなたが投稿すると見られます',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.push('${AppRoutes.camera}?slot=$slotNumber'),
                child: const Text('撮影する'),
              ),
            ] else
              _PostThumbnailRow(posts: [...myPosts, ...othersPosts]),
          ],
        ),
      ),
    );
  }
}

class _PostThumbnailRow extends StatelessWidget {
  const _PostThumbnailRow({required this.posts});

  final List<PostModel> posts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            posts[i].photoUrl,
            width: 100,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 100,
              height: 120,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
