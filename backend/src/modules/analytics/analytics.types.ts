/**
 * File Name: analytics.types.ts
 * Description: Defines response contracts for productivity analytics and
 *              priority suggestion endpoints.
 */

export interface WeeklyBucket {
  /** ISO week start (Monday), YYYY-MM-DD. */
  weekStart: string;
  created: number;
  completed: number;
  /** completed / created within the week, 0 when nothing was created. */
  completionRate: number;
}

export interface ProductivitySummary {
  weeks: WeeklyBucket[];
  totals: {
    created: number;
    completed: number;
    completionRate: number;
    overdueOpen: number;
    completedOnTime: number;
    completedLate: number;
  };
  /** Consecutive days (ending today or yesterday) with at least one completion. */
  currentStreakDays: number;
  generatedAt: string;
}

export interface DayBucket {
  date: string;
  created: number;
  completed: number;
}

export interface MonthBucket {
  month: string;
  created: number;
  completed: number;
}

export interface OverdueTask {
  taskId: string;
  title: string;
  priority: string;
  dueDate: string;
  daysOverdue: number;
}

export interface AnalyticsOverview {
  totalTasks: number;
  active: number;
  completed: number;
  overdueOpen: number;
  completionRate: number;
  createdThisWeek: number;
  completedThisWeek: number;
}

export interface ProductivityOverviewSummary {
  overview: AnalyticsOverview;
  streakDays: number;
  generatedAt: string;
}

export type SuggestedPriority = "low" | "medium" | "high" | "urgent";

export interface PrioritySuggestion {
  taskId: string;
  title: string;
  currentPriority: SuggestedPriority;
  suggestedPriority: SuggestedPriority;
  /** 0-100 urgency score derived from deadline proximity and state. */
  score: number;
  reasons: string[];
  dueDate: string | null;
}

export interface PrioritySuggestionResult {
  suggestions: PrioritySuggestion[];
  evaluatedAt: string;
}
