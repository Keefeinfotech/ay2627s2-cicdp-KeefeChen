import { CalendarRepository } from './calendar.repository';
import { CreateEventDTO, UpdateEventDTO } from './calendar.types';
import { ICalendarEvent } from './calendar.model';

export class CalendarService {
  private repository: CalendarRepository;

  constructor() {
    this.repository = new CalendarRepository();
  }

  async createEvent(
    userId: string,
    data: CreateEventDTO
  ): Promise<ICalendarEvent> {
    return await this.repository.create(userId, data);
  }

  async getEventsForPeriod(
    userId: string,
    startDate: Date,
    endDate: Date,
    groupId?: string
  ): Promise<ICalendarEvent[]> {
    return await this.repository.findByRange(
      userId,
      startDate,
      endDate,
      groupId
    );
  }

  async updateEvent(
    eventId: string,
    userId: string,
    data: UpdateEventDTO
  ): Promise<ICalendarEvent> {
    const existing = await this.repository.findById(eventId);
    if (!existing || existing.userId.toString() !== userId) {
      throw new Error('Calendar event not found or unauthorized');
    }

    const updated = await this.repository.update(eventId, userId, data);
    if (!updated) {
      throw new Error('Failed to update event');
    }
    return updated;
  }

  async deleteEvent(eventId: string, userId: string): Promise<boolean> {
    return await this.repository.delete(eventId, userId);
  }

  async checkConflicts(
    userId: string,
    startTime: Date,
    endTime: Date,
    excludeId?: string
  ) {
    const conflicts = await this.repository.findOverlapping(
      userId,
      startTime,
      endTime,
      excludeId
    );
    return {
      hasConflict: conflicts.length > 0,
      conflictingEvents: conflicts,
    };
  }
}