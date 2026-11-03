/**
 * File Name: roadmap.types.ts
 * Description: Domain types for group study roadmaps.
 * Author: Keefe Chen
 */

export const ROADMAP_STATUSES = [
  "draft",
  "approved",
  "archived",
] as const;

export type RoadmapStatus = (typeof ROADMAP_STATUSES)[number];

export const ROADMAP_SOURCES = ["manual", "rubric"] as const;

export type RoadmapSource = (typeof ROADMAP_SOURCES)[number];

export const ROADMAP_ITEM_STATUSES = [
  "pending",
  "in_progress",
  "done",
  "skipped",
] as const;

export type RoadmapItemStatus = (typeof ROADMAP_ITEM_STATUSES)[number];

export interface RoadmapItemRecord {
  itemId: string;
  title: string;
  description: string | null;
  criterion: string | null;
  weight: number | null;
  estimateHours: number | null;
  status: RoadmapItemStatus;
  order: number;
}

export interface RoadmapRecord {
  _id: string;
  groupId: string;
  title: string;
  description: string | null;
  source: RoadmapSource;
  status: RoadmapStatus;
  createdBy: string;
  approvedAt: Date | null;
  items: RoadmapItemRecord[];
  createdAt: Date;
  updatedAt: Date;
}

export interface RoadmapInputItem {
  title: string;
  description?: string | null;
  criterion?: string | null;
  weight?: number | null;
  estimateHours?: number | null;
  status?: RoadmapItemStatus;
}

export interface CreateRoadmapInput {
  title: string;
  description?: string | null;
  source?: RoadmapSource;
  status?: RoadmapStatus;
  items?: RoadmapInputItem[];
}

export interface UpdateRoadmapInput {
  title?: string;
  description?: string | null;
  status?: RoadmapStatus;
}

export interface UpdateRoadmapItemInput {
  status?: RoadmapItemStatus;
  title?: string;
  estimateHours?: number | null;
}

export type RubricCriterionLike = {
  name: string;
  description: string | null;
  weight: number;
};

export type CreateRoadmapFromRubricInput = {
  groupId: string;
  rubricId: string;
  rubricTitle: string;
  criteria: RubricCriterionLike[];
  createdBy: string;
};
