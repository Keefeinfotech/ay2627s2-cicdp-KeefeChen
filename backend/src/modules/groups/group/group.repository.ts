
/**
 * File Name: group.repository.ts
 * Description: Handles database operations for groups.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";

import { Group } from "./group.model.js";

import {
  GroupStatus,
  type CreateGroupInput,
  type UpdateGroupInput,
} from "./group.types.js";

export class GroupRepository {
  /**
   * Creates a new group.
   */
  async create(
    input: CreateGroupInput & { ownerId: string },
    session?: mongoose.ClientSession
  ) {
    const [group] = await Group.create(
      [
        {
          ...input,
          groupId: undefined,
        },
      ],
      { session }
    );

    return group;
  }

  /**
   * Finds an active group using its public group UUID.
   */
  async findById(groupId: string) {
    return Group.findOne({
      groupId,
      status: GroupStatus.ACTIVE,
    }).lean();
  }

  /**
   * Finds an active group owned by a specific user.
   */
  async findOwned(groupId: string, ownerId: string) {
    return Group.findOne({
      groupId,
      ownerId,
      status: GroupStatus.ACTIVE,
    }).lean();
  }

  /**
   * Updates an active group.
   */
  async update(
    groupId: string,
    ownerId: string,
    input: UpdateGroupInput
  ) {
    return Group.findOneAndUpdate(
      {
        groupId,
        ownerId,
        status: GroupStatus.ACTIVE,
      },
      {
        $set: input,
      },
      {
        new: true,
        runValidators: true,
      }
    ).lean();
  }

  /**
   * Archives an active group.
   */
  async archive(groupId: string, ownerId: string) {
    return Group.findOneAndUpdate(
      {
        groupId,
        ownerId,
        status: GroupStatus.ACTIVE,
      },
      {
        $set: {
          status: GroupStatus.ARCHIVED,
        },
      },
      {
        new: true,
        runValidators: true,
      }
    ).lean();
  }

  /**
   * Lists active groups belonging to the supplied group IDs.
   */
  async list(
    groupIds: string[],
    page: number,
    limit: number,
    search?: string
  ) {
    const filter: Record<string, unknown> = {
      groupId: { $in: groupIds },
      status: GroupStatus.ACTIVE,
    };

    if (search?.trim()) {
      const escapedSearch = search.trim().replace(
        /[.*+?^${}()|[\]\\]/g,
        "\\$&"
      );

      filter.name = {
        $regex: escapedSearch,
        $options: "i",
      };
    }

    const [items, total] = await Promise.all([
      Group.find(filter)
        .sort({ updatedAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),

      Group.countDocuments(filter),
    ]);

    return {
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
