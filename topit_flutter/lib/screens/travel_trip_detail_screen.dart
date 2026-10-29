import 'package:flutter/material.dart';

import '../models/daily_post.dart';
import '../models/travel_trip_record.dart';
import '../services/daily_recap_service.dart';
import '../screens/daily_recap_screen.dart';
import '../widgets/post_timeline.dart';

class TravelTripDetailScreen extends StatelessWidget {
  const TravelTripDetailScreen({
    super.key,
    required this.trip,
    required this.posts,
    required this.isActive,
    required this.onEditPost,
    required this.onDeletePost,
    required this.onDeleteTrip,
  });

  final TravelTripRecord trip;
  final List<DailyPost> posts;
  final bool isActive;
  final ValueChanged<DailyPost> onEditPost;
  final ValueChanged<DailyPost> onDeletePost;
  final Future<bool> Function(TravelTripRecord trip) onDeleteTrip;

  List<DailyPost> get _recapPosts => tripRecapPosts(posts, trip.id);

  void _openRecap(BuildContext context) {
    final recapPosts = _recapPosts;
    final forceView = recapPosts.isEmpty;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => DailyRecapScreen(
              posts: recapPosts,
              forceView: forceView,
              header:
                  forceView
                      ? TravelRecapHeader(
                        itinerary: trip.itinerary,
                        startedAt: trip.startedAt,
                        endedAt: trip.endedAt,
                        showEmptyMessage: true,
                      )
                      : null,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recapPosts = _recapPosts;
    final timelinePosts =
        List<DailyPost>.from(recapPosts)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _shortItinerary(trip.itinerary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!isActive)
            IconButton(
              onPressed: () async {
                final deleted = await onDeleteTrip(trip);
                if (deleted && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              tooltip: '旅を削除',
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Chip(
                avatar: const Icon(Icons.flight_takeoff, size: 18),
                label: const Text('進行中'),
              ),
            ),
          Text(
            trip.itinerary,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _formatPeriod(trip.startedAt, trip.endedAt),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openRecap(context),
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('旅を振り返る'),
          ),
          const SizedBox(height: 20),
          Text(
            'タイムライン',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (timelinePosts.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'まだ写真はありません',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            PostTimeline(
              posts: timelinePosts,
              onEditPost: onEditPost,
              onDeletePost: onDeletePost,
            ),
        ],
      ),
    );
  }

  static String _shortItinerary(String itinerary) {
    final trimmed = itinerary.trim();
    if (trimmed.length <= 24) {
      return trimmed;
    }
    return '${trimmed.substring(0, 24)}…';
  }

  static String _formatPeriod(DateTime startedAt, DateTime endedAt) {
    String format(DateTime value) {
      final local = value.toLocal();
      return '${local.year}/${local.month}/${local.day} '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    return '${format(startedAt)} 〜 ${format(endedAt)}';
  }
}
