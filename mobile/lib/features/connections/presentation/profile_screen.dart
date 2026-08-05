import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/post_model.dart';
import 'widgets/connection_button.dart';

/// Someone's profile — reachable by tapping an avatar/name on a
/// PostCard or the following feed's overlay. [displayName] is passed
/// through navigation (from wherever the tap originated) rather than
/// looked up from a user-profile collection, which doesn't exist in
/// this app — see the design note on Connection in
/// packages/shared-types/src/index.ts.
///
/// Shows the person's public posts only ("下に公開とした投稿が表示" per
/// this session's requirement) — even once connected, this screen
/// doesn't also show their private posts; that's what the following
/// feed is for.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicFeedRepo = ref.watch(publicFeedRepositoryProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUserId;
    final isMe = myUid == uid;

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.coral,
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1) : '?',
                    style: AppTextStyles.displayHeavy.copyWith(color: Colors.white, fontSize: 32),
                  ),
                ),
                const SizedBox(height: 12),
                Text(displayName, style: AppTextStyles.headline),
                if (!isMe) ...[
                  const SizedBox(height: 16),
                  ConnectionButton(targetUid: uid, targetDisplayName: displayName),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('公開した投稿', style: AppTextStyles.bodyStrong),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: publicFeedRepo.watchUserPublicPosts(uid),
              builder: (context, snap) {
                final posts = snap.data ?? const <PostModel>[];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (posts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.photo_outlined,
                    message: '公開された投稿はまだありません',
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return GestureDetector(
                      onTap: () => context.push('${AppRoutes.publicPostDetail}/${post.id}'),
                      child: Image.network(
                        post.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
