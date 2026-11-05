import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/models/task.dart';
import 'package:frontend/features/home/data/gamification.dart';

import '../helpers.dart';

void main() {
  group('XP', () {
    test('awards XP by priority only once per task', () {
      final low = makeTask(
        id: '1',
        priority: TaskPriority.low,
        xpAwarded: true,
      );
      final medium = makeTask(
        id: '2',
        priority: TaskPriority.medium,
        xpAwarded: true,
      );
      final high = makeTask(
        id: '3',
        priority: TaskPriority.high,
        xpAwarded: true,
      );
      final unawarded = makeTask(id: '4', priority: TaskPriority.high);

      expect(Gamification.xpForTask(low), 10);
      expect(Gamification.xpForTask(medium), 20);
      expect(Gamification.xpForTask(high), 30);
      expect(Gamification.xpForTask(unawarded), 0);
      expect(Gamification.totalXp([low, medium, high, unawarded]), 60);
    });

    test('does not deduct XP for reopened tasks', () {
      final reopened = makeTask(
        status: TaskStatus.pending,
        xpAwarded: true,
        priority: TaskPriority.high,
      );
      expect(Gamification.totalXp([reopened]), 30);
    });
  });

  group('levels', () {
    test('uses increasing XP thresholds', () {
      expect(Gamification.xpRequiredForLevel(1), 0);
      expect(Gamification.xpRequiredForLevel(2), 100);
      expect(Gamification.xpRequiredForLevel(3), 300);
      expect(Gamification.xpRequiredForLevel(4), 600);
    });

    test('maps XP to a level at the boundaries', () {
      expect(Gamification.levelForXp(0), 1);
      expect(Gamification.levelForXp(99), 1);
      expect(Gamification.levelForXp(100), 2);
      expect(Gamification.levelForXp(299), 2);
      expect(Gamification.levelForXp(300), 3);
      expect(Gamification.levelForXp(600), 4);
      expect(Gamification.levelForXp(-5), 1);
    });

    test('reports progress within the current level', () {
      final progress = Gamification.progressFor([
        makeTask(priority: TaskPriority.high, xpAwarded: true),
        makeTask(id: '2', priority: TaskPriority.high, xpAwarded: true),
        makeTask(id: '3', priority: TaskPriority.medium, xpAwarded: true),
      ]);

      expect(progress.level, 1);
      expect(progress.totalXp, 80);
      expect(progress.xpIntoLevel, 80);
      expect(progress.xpForNextLevel, 100);
      expect(progress.fraction, closeTo(0.8, 0.0001));
    });
  });

  group('achievements', () {
    test('unlock from persisted task state', () {
      final tasks = <Task>[
        for (var i = 0; i < 5; i++)
          makeTask(
            id: 'done-$i',
            priority: TaskPriority.high,
            status: TaskStatus.completed,
            xpAwarded: true,
          ),
      ];

      final achievements = Gamification.achievementsFor(tasks);
      final byId = <String, Achievement>{
        for (final achievement in achievements) achievement.id: achievement,
      };

      expect(byId['first_step']!.unlocked, isTrue);
      expect(byId['five_done']!.unlocked, isTrue);
      expect(byId['high_five']!.unlocked, isTrue);
      expect(byId['twenty_five']!.unlocked, isFalse);
      expect(byId['planner']!.unlocked, isFalse);
    });
  });
}
