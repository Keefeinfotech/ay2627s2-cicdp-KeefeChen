import { Schema, model, Document, Types } from 'mongoose';

export enum EventPriority {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  URGENT = 'URGENT',
}

export enum EventStatus {
  SCHEDULED = 'SCHEDULED',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export interface ICalendarEvent extends Document {
  userId: Types.ObjectId;
  title: string;
  description?: string;
  startTime: Date;
  endTime: Date;
  isAllDay: boolean;
  priority: EventPriority;
  status: EventStatus;
  location?: string;
  groupId?: Types.ObjectId;
  taskId?: Types.ObjectId;
  recurrence?: {
    frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
    interval?: number;
    until?: Date;
  };
  createdAt: Date;
  updatedAt: Date;
}

const CalendarEventSchema = new Schema<ICalendarEvent>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      trim: true,
      default: '',
    },
    startTime: {
      type: Date,
      required: true,
      index: true,
    },
    endTime: {
      type: Date,
      required: true,
      index: true,
    },
    isAllDay: {
      type: Boolean,
      default: false,
    },
    priority: {
      type: String,
      enum: Object.values(EventPriority),
      default: EventPriority.MEDIUM,
    },
    status: {
      type: String,
      enum: Object.values(EventStatus),
      default: EventStatus.SCHEDULED,
    },
    location: {
      type: String,
      trim: true,
    },
    groupId: {
      type: Schema.Types.ObjectId,
      ref: 'Group',
      default: null,
      index: true,
    },
    taskId: {
      type: Schema.Types.ObjectId,
      ref: 'Task',
      default: null,
    },
    recurrence: {
      frequency: {
        type: String,
        enum: ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'],
      },
      interval: {
        type: Number,
        default: 1,
      },
      until: {
        type: Date,
      },
    },
  },
  {
    timestamps: true,
  }
);

// Compound indexes for range queries and conflict checking
CalendarEventSchema.index({ userId: 1, startTime: 1, endTime: 1 });
CalendarEventSchema.index({ groupId: 1, startTime: 1, endTime: 1 });

export const CalendarEventModel = model<ICalendarEvent>(
  'CalendarEvent',
  CalendarEventSchema
);