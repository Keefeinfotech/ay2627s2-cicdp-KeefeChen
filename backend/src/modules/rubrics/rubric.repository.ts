/**
 * File Name: rubric.repository.ts
 * Description: MongoDB persistence for parsed rubrics.
 * Author: Keefe Chen
 */

import { Rubric } from "./rubric.model.js";

import type { RubricDocument } from "./rubric.model.js";

interface CreateRubricData {
  groupId: string;
  title: string;
  sourceText: string;
  checksum: string;
  version: number;
  criteria: {
    name: string;
    description: string | null;
    weight: number;
  }[];
  createdBy: string;
}

export const rubricRepository = {
  async create(data: CreateRubricData): Promise<RubricDocument> {
    const rubric = await Rubric.create(data);

    return rubric.toObject() as RubricDocument;
  },

  async findById(rubricId: string): Promise<RubricDocument | null> {
    return Rubric.findOne({ _id: rubricId }).lean<RubricDocument>();
  },

  async listByGroup(
    groupId: string,
    page: number,
    limit: number,
  ): Promise<{
    items: RubricDocument[];
    pagination: {
      page: number;
      limit: number;
      totalItems: number;
      totalPages: number;
      hasNextPage: boolean;
      hasPreviousPage: boolean;
    };
  }> {
    const filter = { groupId };

    const skip = (page - 1) * limit;

    const [items, totalItems] = await Promise.all([
      Rubric.find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skip)
        .limit(limit)
        .lean<RubricDocument[]>()
        .exec(),
      Rubric.countDocuments(filter).exec(),
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

  async findDuplicate(
    groupId: string,
    checksum: string,
  ): Promise<RubricDocument | null> {
    return Rubric.findOne({ groupId, checksum })
      .lean<RubricDocument>()
      .exec();
  },

  async remove(rubricId: string, groupId: string): Promise<boolean> {
    const result = await Rubric.deleteOne({
      _id: rubricId,
      groupId,
    }).exec();

    return result.deletedCount === 1;
  },
};
