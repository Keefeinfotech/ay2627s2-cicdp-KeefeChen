/**
 * File Name: analytics.service.ts
 * Description: Aggregates weekly productivity statistics and derives
 *              deadline-driven priority suggestions for open tasks.
 */

import { Task } from "../tasks/task.model.js";
import { cacheGetJson, cacheSetJson } from "../../shared/utils/cache.js";

import type {
  AnalyticsOverview,
  DayBucket,
  MonthBucket,
  OverdueTask,
  PrioritySuggestion,
  PrioritySuggestionResult,
  ProductivityOverviewSummary,
  ProductivitySummary,
  SuggestedPriority,
  WeeklyBucket,
} from "./analytics.types.js";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Returns the Monday (local server time) of the week containing `date`. */
function startOfWeek(date: Date): Date {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  const day = (d.getDay() + 6) % 7; // Monday = 0
  d.setDate(d.getDate() - day);
  return d;
}

function isoDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export const analyticsService = {
  /** Headline numbers for the user's task list. */
  async getOverview(userId: string): Promise<AnalyticsOverview> {
    const now = new Date();
    const weekAgo = new Date(now.getTime() - 7 * MS_PER_DAY);

    const [
      totalTasks,
      completed,
      overdueOpen,
      createdThisWeek,
      completedThisWeek,
    ] = await Promise.all([
      Task.countDocuments({ userId }),
      Task.countDocuments({ userId, status: "completed" }),
      Task.countDocuments({
        userId,
        status: { $in: ["todo", "in_progress"] },
        dueDate: { $lt: now },
      }),
      Task.countDocuments({ userId, createdAt: { $gte: weekAgo } }),
      Task.countDocuments({ userId, completedAt: { $gte: weekAgo } }),
    ]);

    const active = totalTasks - completed;

    return {
      totalTasks,
      active,
      completed,
      overdueOpen,
      completionRate:
        totalTasks === 0 ? 0 : Math.round((completed / totalTasks) * 100) / 100,
      createdThisWeek,
      completedThisWeek,
    };
  },

  /** Per-day created/completed counts over the trailing N days. */
  async getDaily(userId: string, days: number): Promise<DayBucket[]> {
    const clamped = Math.min(Math.max(Math.trunc(days) || 14, 1), 90);
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    start.setDate(start.getDate() - (clamped - 1));

    const [created, completed] = await Promise.all([
      Task.aggregate<{ _id: string; count: number }>([
        { $match: { userId, createdAt: { $gte: start } } },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
            count: { $sum: 1 },
          },
        },
      ]),
      Task.aggregate<{ _id: string; count: number }>([
        { $match: { userId, completedAt: { $gte: start } } },
        {
          $group: {
            _id: {
              $dateToString: { format: "%Y-%m-%d", date: "$completedAt" },
            },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const createdByDay = new Map(created.map((d) => [d._id, d.count]));
    const completedByDay = new Map(completed.map((d) => [d._id, d.count]));

    const buckets: DayBucket[] = [];
    for (let i = 0; i < clamped; i += 1) {
      const day = new Date(start);
      day.setDate(day.getDate() + i);
      const key = isoDate(day);
      buckets.push({
        date: key,
        created: createdByDay.get(key) ?? 0,
        completed: completedByDay.get(key) ?? 0,
      });
    }
    return buckets;
  },

  /** Per-month created/completed counts over the trailing N months. */
  async getMonthly(userId: string, months: number): Promise<MonthBucket[]> {
    const clamped = Math.min(Math.max(Math.trunc(months) || 6, 1), 24);
    const now = new Date();
    const start = new Date(
      now.getFullYear(),
      now.getMonth() - (clamped - 1),
      1,
    );

    const [created, completed] = await Promise.all([
      Task.aggregate<{ _id: string; count: number }>([
        { $match: { userId, createdAt: { $gte: start } } },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m", date: "$createdAt" } },
            count: { $sum: 1 },
          },
        },
      ]),
      Task.aggregate<{ _id: string; count: number }>([
        { $match: { userId, completedAt: { $gte: start } } },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m", date: "$completedAt" } },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const createdByMonth = new Map(created.map((m) => [m._id, m.count]));
    const completedByMonth = new Map(completed.map((m) => [m._id, m.count]));

    const buckets: MonthBucket[] = [];
    for (let i = 0; i < clamped; i += 1) {
      const month = new Date(start.getFullYear(), start.getMonth() + i, 1);
      const key = `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, "0")}`;
      buckets.push({
        month: key,
        created: createdByMonth.get(key) ?? 0,
        completed: completedByMonth.get(key) ?? 0,
      });
    }
    return buckets;
  },

  /** Open tasks past their due date, most overdue first. */
  async getOverdue(userId: string, limit: number): Promise<OverdueTask[]> {
    const clamped = Math.min(Math.max(Math.trunc(limit) || 50, 1), 100);

    const tasks = await Task.find({
      userId,
      status: { $in: ["todo", "in_progress"] },
      dueDate: { $lt: new Date() },
    })
      .select("title priority dueDate")
      .sort({ dueDate: 1 })
      .limit(clamped)
      .lean();

    const now = Date.now();
    return tasks.map((t) => ({
      taskId: String(t._id),
      title: t.title,
      priority: t.priority,
      dueDate: new Date(t.dueDate as Date).toISOString(),
      daysOverdue: Math.floor(
        (now - new Date(t.dueDate as Date).getTime()) / MS_PER_DAY,
      ),
    }));
  },

  /** Completion rate over the trailing N weeks. */
  async getCompletionRate(
    userId: string,
    weeks: number,
  ): Promise<{
    rate: number;
    completed: number;
    created: number;
    weeks: number;
  }> {
    const summary = await analyticsService.getWeeklySummary(userId, weeks);
    return {
      rate: Math.round(summary.totals.completionRate * 100) / 100,
      completed: summary.totals.completed,
      created: summary.totals.created,
      weeks: summary.weeks.length,
    };
  },

  /** Monthly trend with a simple direction signal. */
  async getTaskTrends(
    userId: string,
    months: number,
  ): Promise<{
    months: MonthBucket[];
    direction: "improving" | "declining" | "steady";
  }> {
    const buckets = await analyticsService.getMonthly(userId, months);

    if (buckets.length < 2) {
      return { months: buckets, direction: "steady" };
    }

    const last = buckets[buckets.length - 1].completed;
    const prev = buckets[buckets.length - 2].completed;

    const direction =
      last > prev ? "improving" : last < prev ? "declining" : "steady";

    return { months: buckets, direction };
  },

  /** Combined overview + streak for the productivity dashboard. */
  async getProductivitySummary(
    userId: string,
  ): Promise<ProductivityOverviewSummary> {
    const [overview, weekly] = await Promise.all([
      analyticsService.getOverview(userId),
      analyticsService.getWeeklySummary(userId, 4),
    ]);

    return {
      overview,
      streakDays: weekly.currentStreakDays,
      generatedAt: new Date().toISOString(),
    };
  },

  /**
   * Builds a weekly productivity summary for the given number of weeks
   * (including the current, partial week).
   */
  async getWeeklySummary(
    userId: string,
    weeks: number,
  ): Promise<ProductivitySummary> {
    const clampedWeeks = Math.min(Math.max(Math.trunc(weeks) || 8, 1), 52);

    const cacheKey = `analytics:v1:weekly:${userId}:${clampedWeeks}`;
    const cached = await cacheGetJson<ProductivitySummary>(cacheKey);
    if (cached) return cached;

    const thisWeekStart = startOfWeek(new Date());
    const rangeStart = new Date(thisWeekStart);
    rangeStart.setDate(rangeStart.getDate() - 7 * (clampedWeeks - 1));

    const [createdDocs, completedDocs, completedWithDue, overdueOpen] =
      await Promise.all([
        Task.find({ userId, createdAt: { $gte: rangeStart } })
          .select("createdAt")
          .lean(),
        Task.find({ userId, completedAt: { $gte: rangeStart } })
          .select("completedAt")
          .lean(),
        Task.find({
          userId,
          completedAt: { $gte: rangeStart },
          dueDate: { $ne: null },
        })
          .select("completedAt dueDate")
          .lean(),
        Task.countDocuments({
          userId,
          status: { $in: ["todo", "in_progress"] },
          dueDate: { $lt: new Date() },
        }),
      ]);

    const buckets: WeeklyBucket[] = [];
    for (let i = 0; i < clampedWeeks; i += 1) {
      const weekStart = new Date(rangeStart);
      weekStart.setDate(weekStart.getDate() + 7 * i);
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 7);

      const created = createdDocs.filter(
        (t) => t.createdAt >= weekStart && t.createdAt < weekEnd,
      ).length;
      const completed = completedDocs.filter(
        (t) =>
          t.completedAt &&
          t.completedAt >= weekStart &&
          t.completedAt < weekEnd,
      ).length;

      buckets.push({
        weekStart: isoDate(weekStart),
        created,
        completed,
        completionRate:
          created === 0
            ? completed > 0
              ? 1
              : 0
            : Math.min(completed / created, 1),
      });
    }

    const totalCreated = buckets.reduce((sum, b) => sum + b.created, 0);
    const totalCompleted = buckets.reduce((sum, b) => sum + b.completed, 0);

    const completedOnTime = completedWithDue.filter(
      (t) => t.dueDate && t.completedAt && t.completedAt <= t.dueDate,
    ).length;
    const completedLate = completedWithDue.length - completedOnTime;

    // Streak: consecutive days with >= 1 completion, ending today or yesterday.
    const completionDays = new Set(
      completedDocs
        .filter((t) => t.completedAt)
        .map((t) => isoDate(t.completedAt as Date)),
    );
    let currentStreakDays = 0;
    const cursor = new Date();
    cursor.setHours(0, 0, 0, 0);
    if (!completionDays.has(isoDate(cursor))) {
      cursor.setDate(cursor.getDate() - 1); // allow today to have no completions yet
    }
    while (completionDays.has(isoDate(cursor))) {
      currentStreakDays += 1;
      cursor.setDate(cursor.getDate() - 1);
    }

    const summary: ProductivitySummary = {
      weeks: buckets,
      totals: {
        created: totalCreated,
        completed: totalCompleted,
        completionRate:
          totalCreated === 0
            ? totalCompleted > 0
              ? 1
              : 0
            : Math.min(totalCompleted / totalCreated, 1),
        overdueOpen,
        completedOnTime,
        completedLate,
      },
      currentStreakDays,
      generatedAt: new Date().toISOString(),
    };

    await cacheSetJson(cacheKey, summary, 60);

    return summary;
  },

  /**
   * Scores open tasks by deadline proximity and state, and recommends a
   * priority. Deterministic heuristic; no external AI calls.
   */
  async getPrioritySuggestions(
    userId: string,
    limit: number,
  ): Promise<PrioritySuggestionResult> {
    const clampedLimit = Math.min(Math.max(Math.trunc(limit) || 20, 1), 100);

    const openTasks = await Task.find({
      userId,
      status: { $in: ["todo", "in_progress"] },
    })
      .select("title priority status dueDate")
      .lean();

    const now = Date.now();

    const suggestions: PrioritySuggestion[] = openTasks.map((task) => {
      const reasons: string[] = [];
      let score = 10; // base

      if (task.dueDate) {
        const daysUntilDue = Math.floor(
          (new Date(task.dueDate).getTime() - now) / MS_PER_DAY,
        );

        if (daysUntilDue < 0) {
          score = 100;
          reasons.push(`Overdue by ${-daysUntilDue} day(s)`);
        } else if (daysUntilDue === 0) {
          score = 90;
          reasons.push("Due today");
        } else if (daysUntilDue <= 2) {
          score = 75;
          reasons.push(`Due in ${daysUntilDue} day(s)`);
        } else if (daysUntilDue <= 7) {
          score = 55;
          reasons.push(`Due within a week (${daysUntilDue} day(s))`);
        } else if (daysUntilDue <= 14) {
          score = 35;
          reasons.push(`Due within two weeks (${daysUntilDue} day(s))`);
        } else {
          score = 15;
          reasons.push(`Due in ${daysUntilDue} day(s)`);
        }
      } else {
        reasons.push("No due date set");
      }

      if (task.status === "in_progress") {
        score = Math.min(100, score + 10);
        reasons.push("Already in progress");
      }

      const suggestedPriority: SuggestedPriority =
        score >= 85
          ? "urgent"
          : score >= 60
            ? "high"
            : score >= 30
              ? "medium"
              : "low";

      if (suggestedPriority !== task.priority) {
        reasons.push(`Currently marked as ${task.priority}`);
      }

      return {
        taskId: String(task._id),
        title: task.title,
        currentPriority: task.priority as SuggestedPriority,
        suggestedPriority,
        score,
        reasons,
        dueDate: task.dueDate ? new Date(task.dueDate).toISOString() : null,
      };
    });

    suggestions.sort((a, b) => b.score - a.score);

    return {
      suggestions: suggestions.slice(0, clampedLimit),
      evaluatedAt: new Date().toISOString(),
    };
  },

  /**
   * Applies the computed suggestions to open tasks. Returns the number of
   * tasks whose priority changed.
   */
  async applyPrioritySuggestions(userId: string): Promise<{ updated: number }> {
    const { suggestions } = await this.getPrioritySuggestions(userId, 100);

    const changes = suggestions.filter(
      (s) => s.suggestedPriority !== s.currentPriority,
    );

    if (changes.length === 0) {
      return { updated: 0 };
    }

    await Promise.all(
      changes.map((change) =>
        Task.updateOne(
          {
            _id: change.taskId,
            userId,
            status: { $in: ["todo", "in_progress"] },
          },
          { $set: { priority: change.suggestedPriority } },
        ),
      ),
    );

    return { updated: changes.length };
  },
};
