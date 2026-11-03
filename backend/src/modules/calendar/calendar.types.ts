import { Types } from 'mongoose';
import { EventPriority, EventStatus } from './calendar.model';

export interface CreateEventDTO {
  title: string;
  description?: string;
  startTime: Date;
  endTime: Date;
  isAllDay?: boolean;
  priority?: EventPriority;
  groupId?: string;
  taskId?: string;
  location?: string;
}

export interface UpdateEventDTO {
  title?: string;
  description?: string;
  startTime?: Date;
  endTime?: Date;
  isAllDay?: boolean;
  priority?: EventPriority;
  status?: EventStatus;
  location?: string;
}

export interface CalendarRangeQuery {
  startDate: Date;
  endDate: Date;
  groupId?: string;
}