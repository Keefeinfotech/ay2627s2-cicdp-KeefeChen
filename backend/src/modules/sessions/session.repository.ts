/**
 * File Name: session.repository.ts
 * Description: MongoDB persistence for group study sessions.
 * Author: Keefe Chen
 */

import { StudySession } from "./session.model.js";

import type { StudySessionDocument } from "./session.model.js";
import type { SessionStatus } from "./session.types.js";

interface CreateSessionData {
  groupId: string;
  title: string;
  description: string | null;
  startsAt: Date;
  endsAt: Date;
  location: string | null;
  maxAttendees: number | null;
  createdBy: string;
  attendeeIds: string[];
}

export const sessionRepository = {
  async create(data: CreateSessionData): Promise<StudySessionDocument> {
    const session = await StudySession.create(data);

    return session.toObject() as StudySessionDocument;
  },

  async findById(sessionId: string): Promise<StudySessionDocument | null> {
    return StudySession.findOne({ _id: sessionId }).lean<
      StudySessionDocument
    >();
  },

  async listByGroup(
    groupId: string,
    query: {
      status?: SessionStatus;
      from?: Date;
      to?: Date;
      page: number;
      limit: number;
    },
  ): Promise<{
    items: StudySessionDocument[];
    pagination: {
      page: number;
      limit: number;
      totalItems: number;
      totalPages: number;
      hasNextPage: boolean;
      hasPreviousPage: boolean;
    };
  }> {
    const filter: Record<string, unknown> = { groupId };

    if (query.status) {
      filter.status = query.status;
    }

    if (query.from || query.to) {
      const startsAt: Record<string, Date> = {};

      if (query.from) startsAt.$gte = query.from;
      if (query.to) startsAt.$lte = query.to;

      filter.startsAt = startsAt;
    }

    const skip = (query.page - 1) * query.limit;

    const [items, totalItems] = await Promise.all([
      StudySession.find(filter)
        .sort({ startsAt: 1, _id: 1 })
        .skip(skip)
        .limit(query.limit)
        .lean<StudySessionDocument[]>()
        .exec(),
      StudySession.countDocuments(filter).exec(),
    ]);

    const totalPages = Math.ceil(totalItems / query.limit);

    return {
      items,
      pagination: {
        page: query.page,
        limit: query.limit,
        totalItems,
        totalPages,
        hasNextPage: query.page < totalPages,
        hasPreviousPage: query.page > 1,
      },
    };
  },

  async update(
    sessionId: string,
    groupId: string,
    data: Record<string, unknown>,
  ): Promise<StudySessionDocument | null> {
    return StudySession.findOneAndUpdate(
      { _id: sessionId, groupId },
      { $set: data },
      { new: true, runValidators: true },
    ).lean<StudySessionDocument>();
  },

  /**
   * Joins a scheduled session when there is still capacity.
   */
  async join(
    sessionId: string,
    groupId: string,
    userId: string,
    maxAttendees: number | null,
  ): Promise<StudySessionDocument | null> {
    const capacityFilter: Record<string, unknown> = {};

    if (maxAttendees) {
      capacityFilter.$expr = {
        $lt: [{ $size: "$attendeeIds" }, maxAttendees],
      };
    }

    return StudySession.findOneAndUpdate(
      {
        _id: sessionId,
        groupId,
        status: "scheduled",
        attendeeIds: { $ne: userId },
        ...capacityFilter,
      },
      { $addToSet: { attendeeIds: userId } },
      { new: true },
    ).lean<StudySessionDocument>();
  },

  async leave(
    sessionId: string,
    groupId: string,
    userId: string,
  ): Promise<StudySessionDocument | null> {
    return StudySession.findOneAndUpdate(
      {
        _id: sessionId,
        groupId,
        attendeeIds: userId,
      },
      { $pull: { attendeeIds: userId } },
      { new: true },
    ).lean<StudySessionDocument>();
  },

  async remove(sessionId: string, groupId: string): Promise<boolean> {
    const result = await StudySession.deleteOne({
      _id: sessionId,
      groupId,
    }).exec();

    return result.deletedCount === 1;
  },
};
