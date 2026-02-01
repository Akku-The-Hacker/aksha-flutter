import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/achievement_provider.dart';
import '../../core/models/achievement_model.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementProvider);
    final earnedBadgeTypes = achievements.map((a) => a.badgeType).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Achievements'),
        elevation: 0,
      ),
      body: achievements.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsCard(achievements),
                const SizedBox(height: 24),
                _buildSectionTitle('Earned Badges'),
                const SizedBox(height: 12),
                ...achievements.map((achievement) => _buildAchievementCard(achievement, true)),
                const SizedBox(height: 24),
                _buildSectionTitle('Locked Badges'),
                const SizedBox(height: 12),
                ..._getLockedBadges(earnedBadgeTypes).map((badgeType) => _buildLockedBadgeCard(badgeType)),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No achievements yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete routines to earn badges!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<Achievement> achievements) {
    final uniqueBadges = achievements.length;
    final totalEarned = achievements.fold(0, (sum, a) => sum + a.earnedCount);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(uniqueBadges.toString(), 'Unique Badges', Icons.stars),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            _buildStatItem(totalEarned.toString(), 'Total Earned', Icons.emoji_events),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.amber, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isEarned) {
    final badgeType = achievement.badgeType;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isEarned ? 2 : 0,
      color: isEarned ? null : Colors.grey[100],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEarned ? badgeType.color.withOpacity(0.2) : Colors.grey[300],
          child: Text(
            badgeType.title.split(' ').first, // Get emoji
            style: TextStyle(
              fontSize: 24,
              color: isEarned ? badgeType.color : Colors.grey[500],
            ),
          ),
        ),
        title: Text(
          badgeType.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEarned ? null : Colors.grey[600],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              badgeType.description,
              style: TextStyle(color: isEarned ? null : Colors.grey[500]),
            ),
            if (achievement.earnedCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '✨ Earned ${achievement.earnedCount}x',
                  style: TextStyle(
                    fontSize: 12,
                    color: badgeType.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: isEarned
            ? Icon(Icons.check_circle, color: badgeType.color)
            : Icon(Icons.lock, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildLockedBadgeCard(BadgeType badgeType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.grey[100],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[300],
          child: Text(
            badgeType.title.split(' ').first, // Get emoji
            style: TextStyle(fontSize: 24, color: Colors.grey[500]),
          ),
        ),
        title: Text(
          badgeType.title,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
        ),
        subtitle: Text(
          badgeType.description,
          style: TextStyle(color: Colors.grey[500]),
        ),
        trailing: Icon(Icons.lock, color: Colors.grey[400]),
      ),
    );
  }

  List<BadgeType> _getLockedBadges(Set<BadgeType> earnedBadges) {
    return BadgeType.values.where((type) => !earnedBadges.contains(type)).toList();
  }
}
