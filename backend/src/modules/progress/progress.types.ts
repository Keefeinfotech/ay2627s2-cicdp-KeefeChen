/**
 * File Name: progress.types.ts
 * Description: Response shapes for group progress dashboards.
 * Author: Keefe Chen
 */

export interface GroupProgressResponse {
  groupId: string;
  generatedAt: Date;
  members: {
    total: number;
    owners: number;
    admins: number;
    members: number;
  };
  roadmaps: {
    total: number;
    approved: number;
    items: {
      total: number;
      done: number;
      inProgress: number;
      pending: number;
    };
    completionPercent: number;
  };
  sessions: {
    total: number;
    upcoming: number;
    completed: number;
    cancelled: number;
  };
}
