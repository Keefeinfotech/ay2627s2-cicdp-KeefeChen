/**
 * File Name: roadmap.service.ts
 * Description: Business rules for group roadmaps, including the
 *              deterministic rubric-to-roadmap proposal workflow.
 * Author: Keefe Chen
 */

import { AppError } from "../../shared/utils/AppError.js";
import { AUDIT_ACTIONS } from "../audit/audit.types.js";
import { auditService } from "../audit/audit.service.js";
import {
  GROUP_MANAGER_ROLES,
  requireGroupMembership,
  requireGroupRole,
} from "../groups/shared/membership.js";
import { roadmapRepository } from "./roadmap.repository.js";

import type { RoadmapDocument } from "./roadmap.model.js";
import type {
  CreateRoadmapFromRubricInput,
  CreateRoadmapInput,
  RoadmapStatus,
  UpdateRoadmapInput,
} from "./roadmap.types.js";

const NORMALISED_ROADMAP_ITEM_TITLE = (title: string): string =>
  title.trim();

export const roadmapService = {
  /**
   * Creates an empty or pre-populated roadmap for a group.
   */
  async create(
    groupId: string,
    userId: string,
    input: CreateRoadmapInput,
  ): Promise<RoadmapDocument> {
    await requireGroupRole(groupId, userId, GROUP_MANAGER_ROLES);

    const roadmap = await roadmapRepository.create({
      groupId,
      title: NORMALISED_ROADMAP_ITEM_TITLE(input.title),
      description: input.description ?? null,
      source: input.source ?? "manual",
      status: input.status ?? "draft",
      createdBy: userId,
      items: input.items ?? [],
    });

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.ROADMAP_CREATED,
      targetType: "roadmap",
      targetId: roadmap._id,
      metadata: { itemCount: (input.items ?? []).length },
    });

    return roadmap;
  },

  /**
   * Lists roadmaps for the group.
   */
  async list(
    groupId: string,
    userId: string,
    query: { page?: number; limit?: number; status?: RoadmapStatus },
  ): Promise<{ items: RoadmapDocument[]; pagination: unknown }> {
    await requireGroupMembership(groupId, userId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    return roadmapRepository.listByGroup(groupId, page, limit, query.status);
  },

  /**
   * Retrieves a single roadmap.
   */
  async get(
    groupId: string,
    userId: string,
    roadmapId: string,
  ): Promise<RoadmapDocument> {
    await requireGroupMembership(groupId, userId);

    const roadmap = await roadmapRepository.findById(roadmapId);

    if (!roadmap || roadmap.groupId !== groupId) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    return roadmap;
  },

  /**
   * Updates roadmap details. Only managers may edit roadmaps.
   */
  async update(
    groupId: string,
    userId: string,
    roadmapId: string,
    input: UpdateRoadmapInput,
  ): Promise<RoadmapDocument> {
    await requireGroupRole(groupId, userId, GROUP_MANAGER_ROLES);

    const data: UpdateRoadmapInput = {};

    if (input.title !== undefined) {
      data.title = input.title.trim();
    }

    if (input.description !== undefined) {
      data.description = input.description;
    }

    if (input.status !== undefined) {
      data.status = input.status;
    }

    const roadmap = await roadmapRepository.update(
      roadmapId,
      groupId,
      data as Record<string, unknown>,
    );

    if (!roadmap) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.ROADMAP_UPDATED,
      targetType: "roadmap",
      targetId: roadmap._id,
      metadata: { fields: Object.keys(data) },
    });

    return roadmap;
  },

  /**
   * Approves a draft roadmap. Owner approval is required before group plans
   * are treated as accepted.
   */
  async approve(
    groupId: string,
    userId: string,
    roadmapId: string,
  ): Promise<RoadmapDocument> {
    await requireGroupRole(groupId, userId, GROUP_MANAGER_ROLES);

    const roadmap = await roadmapRepository.findById(roadmapId);

    if (!roadmap || roadmap.groupId !== groupId) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    const approved = await roadmapRepository.update(
      roadmapId,
      groupId,
      {
        status: "approved",
        approvedAt: new Date(),
      },
    );

    if (!approved) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.ROADMAP_APPROVED,
      targetType: "roadmap",
      targetId: roadmapId,
    });

    return approved;
  },

  /**
   * Updates the status of a single roadmap item.
   */
  async updateItem(
    groupId: string,
    userId: string,
    roadmapId: string,
    itemId: string,
    input: { status?: string; title?: string; estimateHours?: number | null },
  ): Promise<RoadmapDocument> {
    await requireGroupMembership(groupId, userId);

    const roadmap = await roadmapRepository.findById(roadmapId);

    if (!roadmap || roadmap.groupId !== groupId) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    const items = [...(roadmap.items ?? [])];
    const index = items.findIndex((item) => item.itemId === itemId);

    if (index === -1) {
      throw new AppError(
        404,
        "ROADMAP_ITEM_NOT_FOUND",
        "Roadmap item was not found.",
      );
    }

    items[index] = {
      ...items[index],
      ...(input.status !== undefined ? { status: input.status } : {}),
      ...(input.title !== undefined ? { title: input.title.trim() } : {}),
      ...(input.estimateHours !== undefined
        ? { estimateHours: input.estimateHours }
        : {}),
    } as (typeof roadmap.items)[number];

    const updated = await roadmapRepository.update(roadmapId, groupId, {
      items,
    });

    if (!updated) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    return updated;
  },

  /**
   * Archives (removes) a roadmap.
   */
  async delete(
    groupId: string,
    userId: string,
    roadmapId: string,
  ): Promise<void> {
    await requireGroupRole(groupId, userId, GROUP_MANAGER_ROLES);

    const removed = await roadmapRepository.remove(roadmapId, groupId);

    if (!removed) {
      throw new AppError(
        404,
        "ROADMAP_NOT_FOUND",
        "Roadmap was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.ROADMAP_DELETED,
      targetType: "roadmap",
      targetId: roadmapId,
    });
  },

  /**
   * Materialises a rubric into a draft roadmap.
   *
   * The generated roadmap is always marked AI-assisted in progress reports by
   * source: "rubric" and must be explicitly approved by a group manager.
   */
  async createFromRubric(
    input: CreateRoadmapFromRubricInput,
  ): Promise<RoadmapDocument> {
    await requireGroupRole(
      input.groupId,
      input.createdBy,
      GROUP_MANAGER_ROLES,
    );

    const items = input.criteria.map((criterion, index) => ({
      title: criterion.name.trim(),
      description: criterion.description,
      criterion: criterion.name.trim(),
      weight: criterion.weight,
      estimateHours: null,
      status: "pending" as const,
      order: index,
    }));

    const roadmap = await roadmapRepository.create({
      groupId: input.groupId,
      title: `${input.rubricTitle} plan`,
      description:
        "Proposal generated from the assessment rubric. Review and approve before it guides the group.",
      source: "rubric",
      status: "draft",
      createdBy: input.createdBy,
      items,
    });

    await auditService.record({
      groupId: input.groupId,
      actorId: input.createdBy,
      action: AUDIT_ACTIONS.ROADMAP_CREATED,
      targetType: "roadmap",
      targetId: roadmap._id,
      metadata: { source: "rubric", rubricId: input.rubricId },
    });

    return roadmap;
  },
};
