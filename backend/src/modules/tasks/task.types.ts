
/**
 * File Name: task.types.ts
 * Description: Defines task domain types, filtering parameters, and paginated response contracts.
 * Author: Keefe Chen
 */

// ============================================================================
// TASK ENUMERATIONS
// ============================================================================

export const TASK_STATUSES = [
  "todo",
  "in_progress",
  "completed",
  "archived",
] as const;

export type TaskStatus = (typeof TASK_STATUSES)[number];

export const TASK_PRIORITIES = [
  "low",
  "medium",
  "high",
  "urgent",
] as const;

export type TaskPriority = (typeof TASK_PRIORITIES)[number];

export const TASK_SORT_FIELDS = [
  "createdAt",
  "updatedAt",
  "dueDate",
  "priority",
  "title",
] as const;

export type TaskSortField = (typeof TASK_SORT_FIELDS)[number];

export type SortOrder = "asc" | "desc";

// ============================================================================
// TASK DOMAIN MODEL
// ============================================================================

/**
 * Represents a persisted task record in the domain model.
 */
export interface TaskRecord {
  _id: string;
  userId: string;
  title: string;
  description: string | null;
  course: string;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: Date | null;
  reminderAt: Date | null;
  completedAt: Date | null;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

// ============================================================================
// TASK INPUT CONTRACTS
// ============================================================================

/**
 * Payload data accepted when creating a task.
 */
export interface CreateTaskInput {
  id?: string;
  title: string;
  description?: string | null;
  course?: string;
  reminderAt?: Date | null;
  priority?: TaskPriority;
  dueDate?: Date | null;
}

/**
 * Payload data accepted when updating an existing task.
 */
export interface UpdateTaskInput {
  title?: string;
  description?: string | null;
  course?: string;
  reminderAt?: Date | null;
  priority?: TaskPriority;
  status?: TaskStatus;
  dueDate?: Date | null;
}

// ============================================================================
// TASK FILTERING
// ============================================================================

/**
 * Shared query options for searching, filtering, and sorting tasks.
 */
export interface ListTasksFilterOptions {
  search?: string;
  status?: TaskStatus | TaskStatus[];
  priority?: TaskPriority | TaskPriority[];
  dueBefore?: Date;
  dueAfter?: Date;
  completedBefore?: Date;
  completedAfter?: Date;
  includeDeleted?: boolean;
}

// ============================================================================
// PAGINATION INPUT CONTRACTS
// ============================================================================

/**
 * Standard offset-based pagination.
 *
 * Suitable for numbered pages and Previous/Next navigation.
 */
export interface OffsetPaginationInput
  extends ListTasksFilterOptions {
  paginationType?: "offset";
  page?: number;
  limit?: number;
  sortBy?: TaskSortField;
  sortOrder?: SortOrder;
}

/**
 * Cursor-based pagination.
 *
 * Suitable for infinite scrolling and large datasets.
 */
export interface CursorPaginationInput
  extends ListTasksFilterOptions {
  paginationType: "cursor";
  cursor?: string;
  limit?: number;
  sortBy?: TaskSortField;
  sortOrder?: SortOrder;
}

/**
 * Supported task listing pagination strategies.
 */
export type ListTasksInput =
  | OffsetPaginationInput
  | CursorPaginationInput;

// ============================================================================
// PAGINATION RESPONSE CONTRACTS
// ============================================================================

/**
 * Metadata returned for offset-based pagination.
 */
export interface OffsetPaginationMeta {
  page: number;
  limit: number;
  totalItems: number;
  totalPages: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}

/**
 * Offset-paginated task response.
 */
export interface OffsetPaginatedTasks {
  type: "offset";
  items: TaskRecord[];
  pagination: OffsetPaginationMeta;
}

/**
 * Metadata returned for cursor-based pagination.
 */
export interface CursorPaginationMeta {
  limit: number;
  nextCursor: string | null;
  previousCursor: string | null;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}

/**
 * Cursor-paginated task response.
 */
export interface CursorPaginatedTasks {
  type: "cursor";
  items: TaskRecord[];
  pagination: CursorPaginationMeta;
}

/**
 * Consolidated paginated task response.
 */
export type PaginatedTasks =
  | OffsetPaginatedTasks
  | CursorPaginatedTasks;
