import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/models/post_model.dart';
import '../../../connections/presentation/widgets/connection_button.dart';

/// Instagram-post-style card: avatar + name header (tap to open their
/// profile — "投稿からフォロー申請が行えたり" per this session's
/// direction, now a 友達 request via ConnectionButton), full-width photo
/// with the prompt shown as a corner badge (per this session's
/// "お題も上部に表示"), like/comment action row, caption. Used by
/// PublicFeedScreen's list; PostDetailScreen reuses everything above the
/// comment list via showCommentsLink: false there, since its own comment
/// list below covers that.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onOpenComments,
    this.showCommentsLink = true,
  });

  final PostModel post;
  final VoidCallback onOpenComments;

  /// False on PostDetailScreen, which already IS the comments view — a
  /// "コメントを見る" link back to itself would be pointless there.
  final bool showCommentsLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(publicFeedRepositoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push(
                    '${AppRoutes.profile}/${post.userId}'
                    '?name=${Uri.encodeComponent(post.authorDisplayName)}',
                  ),
                  child: Row(
                    children: [
                      _AuthorAvatar(name: post.authorDisplayName),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(post.authorDisplayName, style: AppTextStyles.bodyStrong),
                            Text(
                              relativeTimeJa(post.postedAt),
                              style: AppTextStyles.caption
                                  .copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConnectionButton(
                targetUid: post.userId,
                targetDisplayName: post.authorDisplayName,
                compact: true,
              ),
            ],
          ),
        ),
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Image.network(
                post.photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            Positioned(top: 10, right: 10, child: _PromptBadge(text: post.promptText)),
          ],
        ),
        StreamBuilder<bool>(
          stream: repo.watchIsLikedByMe(post.id),
          builder: (context, likedSnap) {
            final isLiked = likedSnap.data ?? false;
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppColors.coral : colorScheme.onSurface,
                    ),
                    onPressed: () => repo.setLiked(post.id, !isLiked),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mode_comment_outlined),
                    onPressed: onOpenComments,
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            '${post.likeCount}件のいいね',
            style: AppTextStyles.bodyStrong,
          ),
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.body.copyWith(color: colorScheme.onSurface),
                children: [
                  TextSpan(text: '${post.authorDisplayName} ', style: AppTextStyles.bodyStrong),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
        if (showCommentsLink)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GestureDetector(
              onTap: onOpenComments,
              child: Text(
                'コメントを見る',
                style: AppTextStyles.caption.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    return CircleAvatar(
      radius: 18,
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

class _PromptBadge extends StatelessWidget {
  const _PromptBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
