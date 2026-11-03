/**
 * File Name: rubric.service.ts
 * Description: Parses pasted rubric text into weighted criteria and
 *              proposes roadmaps from the structured result.
 * Author: Keefe Chen
 */

import { createHash } from "node:crypto";

import { AppError } from "../../shared/utils/AppError.js";
import { AUDIT_ACTIONS } from "../audit/audit.types.js";
import { auditService } from "../audit/audit.service.js";
import {
  GROUP_MANAGER_ROLES,
  requireGroupMembership,
  requireGroupRole,
} from "../groups/shared/membership.js";
import { roadmapService } from "../roadmaps/roadmap.service.js";
import { rubricRepository } from "./rubric.repository.js";
import { RUBRIC_VERSION } from "./rubric.types.js";

import type { RubricDocument } from "./rubric.model.js";
import type { RubricCriterion } from "./rubric.types.js";

/**
 * Parses one or more criteria from a rubric line.
 *
 * Supported shapes (one criterion per line):
 *   Criterion name | 30 | Rewarding clear structure
 *   Criterion name - 30%
 *   Criterion name (30%)
 *   Criterion name
 */
export function parseCriteria(sourceText: string): RubricCriterion[] {
  const criteria: { name: string; description: string | null; weight: number }[] =
    [];

  const lines = sourceText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  for (const line of lines) {
    if (/^(table|rubric|assessment|criteria|task|assignment)$/i.test(line)) {
      continue;
    }

    const numbered = line.replace(/^\s*(?:[-*•]|\d+[.)])\s+/, "");

    // Shape 1: "Name | weight | description"
    const piped = numbered
      .split("|")
      .map((part) => part.trim())
      .filter((part) => part.length > 0);

    if (piped.length >= 2) {
      const name = piped[0];
      const weightPart = piped[1];
      const description =
        piped.length >= 3 ? piped.slice(2).join(" | ") : null;

      const weight = parseWeight(weightPart);

      if (name.length > 0 && weight !== null) {
        pushCriterion(criteria, { name, description, weight });
        continue;
      }
    }

    // Shape 2: "Name - 30%" or "Name (30%)"
    const separate = numbered.match(
      /^(.+?)\s*(?:[-–—:]\s*)?\(?(\d+(?:\.\d+)?)\s*%?\)?\s*$/,
    );

    if (separate && separate[2]) {
      const name = separate[1].replace(/[-–—:]\s*$/, "").trim();
      const weight = Number(separate[2]);
      const isWeightOnly =
        /%/.test(numbered) || !/\d/.test(name);

      if (name.length > 0 && isWeightOnly) {
        pushCriterion(criteria, {
          name,
          description: null,
          weight: clampWeight(weight),
        });
        continue;
      }
    }

    // Shape 3: plain criterion line with equal weight applied later.
    if (numbered.length > 0) {
      pushCriterion(criteria, { name: numbered, description: null, weight: 0 });
    }
  }

  return normaliseWeights(criteria);
}

const pushCriterion = (
  criteria: { name: string; description: string | null; weight: number }[],
  candidate: { name: string; description: string | null; weight: number },
): void => {
  const name = candidate.name.replace(/[:.、,]+$/, "").trim();

  if (!name || name.length < 2) return;
  if (criteria.length >= 50) return;

  criteria.push({
    name,
    description: candidate.description,
    weight: candidate.weight,
  });
};

const parseWeight = (value: string): number | null => {
  const percent = value.match(/^(\d+(?:\.\d+)?)\s*%?$/);

  if (!percent) {
    return null;
  }

  return clampWeight(Number(percent[1]));
};

const clampWeight = (weight: number): number =>
  Math.min(Math.max(weight, 0), 100);

function normaliseWeights(
  criteria: { name: string; description: string | null; weight: number }[],
): RubricCriterion[] {
  if (criteria.length === 0) {
    return [];
  }

  const declared = criteria.filter((criterion) => criterion.weight > 0);
  const useDeclared = declared.length === criteria.length && declared.length > 0;

  if (useDeclared) {
    const total = criteria.reduce(
      (sum, criterion) => sum + criterion.weight,
      0,
    );

    if (total === 100) {
      return criteria.map((criterion) => ({
        ...criterion,
        weight: round2(criterion.weight),
      }));
    }

    // Rescale whenever the declared percentages do not sum to 100 exactly.
    return criteria.map((criterion) => ({
      ...criterion,
      weight: round2((criterion.weight / total) * 100),
    }));
  }

  // Structured weights present for some, but not all, criteria: keep the
  // declared weights and share nothing back onto unweighted criteria, so
  // marker evidence is never silently reweighted.
  if (declared.length > 0) {
    return criteria.map((criterion) => ({
      ...criterion,
      weight: round2(criterion.weight),
    }));
  }

  const equal = round2(100 / criteria.length);

  return criteria.map((criterion) => ({
    name: criterion.name,
    description: criterion.description,
    weight: equal,
  }));
}

const round2 = (value: number): number =>
  Math.round(value * 100) / 100;

export const rubricService = {
  /**
   * Parses pasted rubric text into a structured, checksummed rubric.
   */
  async create(
    groupId: string,
    userId: string,
    input: { title: string; sourceText: string },
  ): Promise<RubricDocument> {
    await requireGroupRole(groupId, userId, GROUP_MANAGER_ROLES);

    const criteria = parseCriteria(input.sourceText);

    if (criteria.length === 0) {
      throw new AppError(
        400,
        "RUBRIC_NO_CRITERIA",
        "No rubric criteria could be identified. Use one criterion per line, optionally with its weight (for example 'Clear structure | 30%').",
      );
    }

    const checksum = checksumOf(input.sourceText);

    const duplicate = await rubricRepository.findDuplicate(
      groupId,
      checksum,
    );

    if (duplicate) {
      return duplicate;
    }

    const rubric = await rubricRepository.create({
      groupId,
      title: input.title.trim(),
      sourceText: input.sourceText,
      checksum,
      version: RUBRIC_VERSION,
      criteria,
      createdBy: userId,
    });

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.RUBRIC_PARSED,
      targetType: "rubric",
      targetId: rubric._id,
      metadata: { criterionCount: criteria.length, checksum },
    });

    return rubric;
  },

  /**
   * Lists rubrics for the group.
   */
  async list(
    groupId: string,
    userId: string,
    query: { page?: number; limit?: number },
  ) {
    await requireGroupMembership(groupId, userId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    return rubricRepository.listByGroup(groupId, page, limit);
  },

  /**
   * Retrieves a single rubric.
   */
  async get(
    groupId: string,
    userId: string,
    rubricId: string,
  ): Promise<RubricDocument> {
    await requireGroupMembership(groupId, userId);

    const rubric = await rubricRepository.findById(rubricId);

    if (!rubric || rubric.groupId !== groupId) {
      throw new AppError(
        404,
        "RUBRIC_NOT_FOUND",
        "Rubric was not found.",
      );
    }

    return rubric;
  },

  /**
   * Generates an editable roadmap proposal from an existing rubric.
   */
  async createRoadmapProposal(
    groupId: string,
    userId: string,
    rubricId: string,
  ): Promise<{
    rubricId: string;
    proposal: {
      roadmapId: string;
      draftStatus: string;
      itemCount: number;
    };
  }> {
    const rubric = await rubricService.get(groupId, userId, rubricId);

    const roadmap =
      await roadmapService.createFromRubric({
        groupId,
        rubricId,
        rubricTitle: rubric.title,
        criteria: rubric.criteria.map((criterion) => ({
          name: criterion.name,
          description: criterion.description ?? null,
          weight: criterion.weight,
        })),
        createdBy: userId,
      });

    return {
      rubricId,
      proposal: {
        roadmapId: roadmap._id ?? "",
        draftStatus: roadmap.status ?? "draft",
        itemCount: roadmap.items?.length ?? 0,
      },
    };
  },

  /**
   * Deletes a rubric permanently.
   */
  async delete(
    groupId: string,
    userId: string,
    rubricId: string,
  ): Promise<void> {
    await requireGroupRole(groupId, userId, GROUP_MANAGER_ROLES);

    const removed = await rubricRepository.remove(rubricId, groupId);

    if (!removed) {
      throw new AppError(
        404,
        "RUBRIC_NOT_FOUND",
        "Rubric was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.RUBRIC_DELETED,
      targetType: "rubric",
      targetId: rubricId,
    });
  },
};

const checksumOf = (sourceText: string): string => {
  const normalised = sourceText.replace(/\r\n/g, "\n").trim();

  return createHash("sha256").update(normalised).digest("hex");
};
