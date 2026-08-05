import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_pill.dart';
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

/// 24:00 JST today (== 00:00 JST tomorrow) — slot 3's deadline per the
/// design doc ("お題3: 当日24:00まで(カウントダウン表示)").
DateTime _todayMidnightDeadlineJst(String dateId) {
  return DateTime.parse('${dateId}T00:00:00+09:00').add(const Duration(days: 1));
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
            body: EmptyState(
              icon: Icons.group_add_outlined,
              message: 'まだグループに参加していません。\n作成するか、招待コードで参加しましょう。',
              actionLabel: 'グループに参加 / 作成する',
              onAction: () => context.push(AppRoutes.groupSetup),
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
        title: Row(
          children: [
            _GroupAvatar(name: group.name),
            const SizedBox(width: 10),
            Flexible(child: Text(group.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
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
            return const EmptyState(
              icon: Icons.schedule_outlined,
              message: '本日のお題はまだ設定されていません。\nしばらくしてからもう一度確認してください。',
            );
          }
          return StreamBuilder<List<PostModel>>(
            stream: repo.watchGroupPosts(group.id, dateId),
            builder: (context, postsSnap) {
              final allPosts = postsSnap.data ?? const <PostModel>[];
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: schedule.slots.length,
                itemBuilder: (context, index) {
                  final slotNumber = index + 1;
                  final slotPosts =
                      allPosts.where((p) => p.slotNumber == slotNumber).toList(growable: false);
                  return _SlotCard(
                    dateId: dateId,
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

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    // substring(0,1) rather than the `characters` package's grapheme-aware
    // .characters.first — good enough for a group-name initial (virtually
    // always a single BMP code unit for Japanese/Latin text) without an
    // extra import for an edge case (multi-code-unit emoji names) this
    // avatar doesn't need to handle precisely.
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initial,
        style: AppTextStyles.bodyStrong.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.dateId,
    required this.slotNumber,
    required this.slot,
    required this.slotPosts,
    required this.myUid,
  });

  final String dateId;
  final int slotNumber;
  final ScheduleSlot? slot;
  final List<PostModel> slotPosts;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (slot == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _SlotNumberBadge(number: slotNumber, active: false),
              const SizedBox(width: 12),
              Text(
                'まだお題が設定されていません',
                style: AppTextStyles.body.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final myPosts = slotPosts.where((p) => p.userId == myUid).toList(growable: false);
    final hasPosted = myPosts.isNotEmpty;
    final othersPosts = slotPosts.where((p) => p.userId != myUid).toList(growable: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SlotNumberBadge(number: slotNumber, active: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot!.promptText, style: AppTextStyles.title.copyWith(
                        color: colorScheme.onSurface,
                      )),
                      const SizedBox(height: 2),
                      Text(
                        slot!.credit.when(
                          admin: () => '運営考案',
                          user: (_, displayName) => '$displayNameさん考案',
                        ),
                        style: AppTextStyles.caption.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (hasPosted)
                  const StatusPill(label: '投稿済み', tone: StatusTone.positive, icon: Icons.check)
                else if (slotNumber == 3)
                  CountdownText(deadline: _todayMidnightDeadlineJst(dateId))
                else
                  const StatusPill(label: '未投稿', tone: StatusTone.neutral),
              ],
            ),
            const SizedBox(height: 14),
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
                style: AppTextStyles.caption.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('${AppRoutes.camera}?slot=$slotNumber'),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('撮影する'),
                ),
              ),
            ] else
              _PostGallery(myPost: myPosts.first, othersPosts: othersPosts),
          ],
        ),
      ),
    );
  }
}

class _SlotNumberBadge extends StatelessWidget {
  const _SlotNumberBadge({required this.number, required this.active});

  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$number',
        style: AppTextStyles.title.copyWith(
          color: active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "Your photo" gets pride of place (large), groupmates' photos trail in
/// a horizontal strip — a nod to BeReal's primary/secondary dual-photo
/// framing without literally copying its front/back camera gimmick
/// (PingPic only ever captures one photo per slot).
class _PostGallery extends StatelessWidget {
  const _PostGallery({required this.myPost, required this.othersPosts});

  final PostModel myPost;
  final List<PostModel> othersPosts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: _NetworkPhoto(url: myPost.photoUrl),
          ),
        ),
        if (othersPosts.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: othersPosts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70,
                  height: 88,
                  child: _NetworkPhoto(url: othersPosts[i].photoUrl),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.mutedLight.withOpacity(0.1),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
