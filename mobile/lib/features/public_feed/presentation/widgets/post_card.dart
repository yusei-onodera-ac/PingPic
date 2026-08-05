import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/models/post_model.dart';

/// Instagram-post-style card: avatar + name header (with the prompt
/// shown as a small badge, per this session's "お題も上部に表示"
/// requirement), full-width photo, like/comment action row, caption.
/// Used by PublicFeedScreen's list; PostDetailScreen reuses everything
/// above the comment list via [showFullComments]: false there too, since
/// its own comment list below covers that.
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
              _AuthorAvatar(name: post.authorDisplayName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorDisplayName, style: AppTextStyles.bodyStrong),
                    Text(
                      relativeTimeJa(post.postedAt),
                      style: AppTextStyles.caption.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _PromptBadge(text: post.promptText),
            ],
          ),
        ),
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
      constraints: const BoxConstraints(maxWidth: 110),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
