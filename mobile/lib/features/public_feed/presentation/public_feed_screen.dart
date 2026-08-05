import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/models/post_model.dart';
import '../data/public_feed_repository.dart';
import 'widgets/post_card.dart';

/// "みんなの投稿" — every user's public posts, mixed across prompts,
/// dates, and groups (not scoped to "today" or a single prompt — see
/// this session's "複数のお題の投稿がランダムで表示されているイメージ").
/// Defaults to most-liked-first per "いいねが多い投稿が積極的に優先されて
/// 表示される", with a toggle to switch to newest-first.
class PublicFeedScreen extends ConsumerStatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  ConsumerState<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends ConsumerState<PublicFeedScreen> {
  PublicFeedSort _sort = PublicFeedSort.mostLiked;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(publicFeedRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('みんなの投稿'),
        actions: [
          SegmentedButton<PublicFeedSort>(
            segments: const [
              ButtonSegment(
                value: PublicFeedSort.mostLiked,
                icon: Icon(Icons.favorite, size: 16),
                label: Text('人気'),
              ),
              ButtonSegment(
                value: PublicFeedSort.newest,
                icon: Icon(Icons.schedule, size: 16),
                label: Text('新着'),
              ),
            ],
            selected: {_sort},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() => _sort = selection.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: repo.watchPublicPosts(sort: _sort),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snap.data ?? const <PostModel>[];
          if (posts.isEmpty) {
            return const EmptyState(
              icon: Icons.public_off_outlined,
              message: 'まだ公開されている投稿がありません。\n撮影した写真を「公開する」にして共有してみましょう。',
            );
          }
          return ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onOpenComments: () => context.push('${AppRoutes.publicPostDetail}/${post.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
