import { CalendarEventModel, ICalendarEvent } from "./calendar.model";
import { CreateEventDTO, UpdateEventDTO } from "./calendar.types";
import { Types } from "mongoose";

/**
 * Allowlist patterns for user-supplied identifiers. Values that do not match
 * are rejected before they reach a Mongo query (defense in depth on top of
 * the route-level validators).
 */
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const requireUuid = (value: string, field: string): string => {
  if (!UUID_PATTERN.test(value)) {
    throw new Error(`Invalid ${field}`);
  }
  return value;
};

export class CalendarRepository {
  async create(userId: string, data: CreateEventDTO): Promise<ICalendarEvent> {
    const event = new CalendarEventModel({
      ...data,
      userId,
      groupId: data.groupId
        ? requireUuid(String(data.groupId), "groupId")
        : undefined,
      taskId: data.taskId
        ? requireUuid(String(data.taskId), "taskId")
        : undefined,
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
      query.groupId = requireUuid(groupId, "groupId");
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
      if (!Types.ObjectId.isValid(excludeEventId)) {
        throw new Error("Invalid excludeEventId");
      }
      query._id = { $ne: new Types.ObjectId(excludeEventId) };
    }

    return await CalendarEventModel.find(query).exec();
  }
}
