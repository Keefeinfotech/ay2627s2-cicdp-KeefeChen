/**
 * File Name: roadmap.repository.ts
 * Description: MongoDB persistence for group roadmaps.
 * Author: Keefe Chen
 */

import { Roadmap } from "./roadmap.model.js";

import type { RoadmapDocument } from "./roadmap.model.js";
import type { RoadmapStatus } from "./roadmap.types.js";

interface CreateRoadmapData {
  groupId: string;
  title: string;
  description?: string | null;
  source: "manual" | "rubric";
  status: RoadmapStatus;
  createdBy: string;
  items: unknown[];
}

export const roadmapRepository = {
  async create(data: CreateRoadmapData): Promise<RoadmapDocument> {
    const roadmap = await Roadmap.create(data);

    return roadmap.toObject() as RoadmapDocument;
  },

  async findById(
    roadmapId: string,
  ): Promise<RoadmapDocument | null> {
    return Roadmap.findOne({ _id: roadmapId }).lean<RoadmapDocument>();
  },

  async listByGroup(
    groupId: string,
    page: number,
    limit: number,
    status?: RoadmapStatus,
  ): Promise<{
    items: RoadmapDocument[];
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

    if (status) {
      filter.status = status;
    }

    const skip = (page - 1) * limit;

    const [items, totalItems] = await Promise.all([
      Roadmap.find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skip)
        .limit(limit)
        .lean<RoadmapDocument[]>()
        .exec(),
      Roadmap.countDocuments(filter).exec(),
    ]);

    const totalPages = Math.ceil(totalItems / limit);

    return {
      items,
      pagination: {
        page,
        limit,
        totalItems,
        totalPages,
        hasNextPage: page < totalPages,
        hasPreviousPage: page > 1,
      },
    };
  },

  async update(
    roadmapId: string,
    groupId: string,
    data: Record<string, unknown>,
  ): Promise<RoadmapDocument | null> {
    return Roadmap.findOneAndUpdate(
      { _id: roadmapId, groupId },
      { $set: data },
      { new: true, runValidators: true },
    ).lean<RoadmapDocument>();
  },

  async remove(
    roadmapId: string,
    groupId: string,
  ): Promise<boolean> {
    const result = await Roadmap.deleteOne({
      _id: roadmapId,
      groupId,
    }).exec();

    return result.deletedCount === 1;
  },
};
