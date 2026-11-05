/**
 * File Name: sync.model.ts
 * Description: Database entity representations and mapping helpers for task sync changes.
 * Author: Keefe Chen
 */

import { TaskChange } from './sync.types';

export class TaskChangeModel implements TaskChange {
  id!: string;
  userId!: string;
  title!: string;
  description!: string | null;
  course!: string;
  reminderAt!: Date | null;
  status!: string;
  priority!: string;
  dueDate!: Date | null;
  completedAt!: Date | null;
  deletedAt!: Date | null;
  updatedAt!: Date;
  createdAt!: Date;

  constructor(partial: Partial<TaskChangeModel>) {
    Object.assign(this, partial);
    this.reminderAt = partial.reminderAt ? new Date(partial.reminderAt) : null;
    this.dueDate = partial.dueDate ? new Date(partial.dueDate) : null;
    this.completedAt = partial.completedAt ? new Date(partial.completedAt) : null;
    this.deletedAt = partial.deletedAt ? new Date(partial.deletedAt) : null;
    this.updatedAt = partial.updatedAt ? new Date(partial.updatedAt) : new Date();
    this.createdAt = partial.createdAt ? new Date(partial.createdAt) : new Date();
  }

  /**
   * Serializes entity dates to ISO strings for API transmission.
   */
  public toJSON() {
    return {
      ...this,
      reminderAt: this.reminderAt?.toISOString() ?? null,
      dueDate: this.dueDate?.toISOString() ?? null,
      completedAt: this.completedAt?.toISOString() ?? null,
      deletedAt: this.deletedAt?.toISOString() ?? null,
      updatedAt: this.updatedAt.toISOString(),
      createdAt: this.createdAt.toISOString(),
    };
  }
}