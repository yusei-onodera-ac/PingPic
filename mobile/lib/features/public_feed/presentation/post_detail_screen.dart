import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/models/post_model.dart';
import 'widgets/post_card.dart';

/// Full post view: PostCard's header/photo/actions (minus the
/// self-referential "コメントを見る" link) plus the live comment list and
/// an add-comment field. Reached from PublicFeedScreen's PostCard tap.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(publicFeedRepositoryProvider).addComment(widget.postId, text);
      _commentController.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(publicFeedRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('投稿')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
              builder: (context, postSnap) {
                if (postSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = postSnap.data?.data();
                if (data == null) {
                  return const Center(child: Text('投稿が見つかりません'));
                }
                final post = PostModel.fromJson({...data, 'id': widget.postId});

                return ListView(
                  children: [
                    PostCard(post: post, onOpenComments: () {}, showCommentsLink: false),
                    const Divider(height: 1),
                    StreamBuilder<List<CommentModel>>(
                      stream: repo.watchComments(widget.postId),
                      builder: (context, commentsSnap) {
                        final comments = commentsSnap.data ?? const <CommentModel>[];
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('まだコメントはありません')),
                          );
                        }
                        return Column(
                          children: comments.map((c) => _CommentTile(comment: c)).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLength: 280,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                          null,
                      decoration: const InputDecoration(hintText: 'コメントを追加…'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              comment.displayName.isNotEmpty ? comment.displayName.substring(0, 1) : '?',
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    children: [
                      TextSpan(text: '${comment.displayName} ', style: AppTextStyles.bodyStrong),
                      TextSpan(text: comment.text),
                    ],
                  ),
                ),
                Text(
                  relativeTimeJa(comment.createdAt),
                  style: AppTextStyles.caption
                      .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
