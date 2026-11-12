import { CalendarEventModel, ICalendarEvent } from "./calendar.model";
import { CreateEventDTO, UpdateEventDTO } from "./calendar.types";

export class CalendarRepository {
  async create(userId: string, data: CreateEventDTO): Promise<ICalendarEvent> {
    const event = new CalendarEventModel({
      ...data,
      userId,
      groupId: data.groupId ? data.groupId : undefined,
      taskId: data.taskId ? data.taskId : undefined,
    });
    return await event.save();
  }

  async findById(eventId: string): Promise<ICalendarEvent | null> {
    return await CalendarEventModel.findById(eventId).exec();
  }

  async findByRange(
    userId: string,
    startDate: Date,
    endDate: Date,
    groupId?: string,
  ): Promise<ICalendarEvent[]> {
    const query: any = {
      userId,
      startTime: { $lte: endDate },
      endTime: { $gte: startDate },
    };

    if (groupId) {
      query.groupId = groupId;
    }

    return await CalendarEventModel.find(query).sort({ startTime: 1 }).exec();
  }

  async update(
    eventId: string,
    userId: string,
    data: UpdateEventDTO,
  ): Promise<ICalendarEvent | null> {
    return await CalendarEventModel.findOneAndUpdate(
      { _id: eventId, userId },
      { $set: data },
      { new: true },
    ).exec();
  }

  async delete(eventId: string, userId: string): Promise<boolean> {
    const result = await CalendarEventModel.deleteOne({
      _id: eventId,
      userId,
    }).exec();
    return result.deletedCount > 0;
  }

  async findOverlapping(
    userId: string,
    startTime: Date,
    endTime: Date,
    excludeEventId?: string,
  ): Promise<ICalendarEvent[]> {
    const query: any = {
      userId,
      startTime: { $lt: endTime },
      endTime: { $gt: startTime },
    };

    if (excludeEventId) {
      query._id = { $ne: excludeEventId };
    }

    return await CalendarEventModel.find(query).exec();
  }
}
