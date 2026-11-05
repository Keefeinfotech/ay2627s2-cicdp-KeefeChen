/**
 * File Name: rubric.types.ts
 * Description: Domain types for parsed assessment rubrics.
 * Author: Keefe Chen
 */

export const RUBRIC_VERSION = 1;

export interface RubricCriterion {
  name: string;
  description: string | null;
  weight: number;
}

export interface RubricRecord {
  _id: string;
  groupId: string;
  title: string;
  sourceText: string;
  checksum: string;
  version: number;
  criteria: RubricCriterion[];
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface ParseRubricInput {
  title: string;
  sourceText: string;
}

export interface RubricProposalResult {
  rubricId: string;
  proposal: {
    roadmapId: string;
    draftStatus: string;
    itemCount: number;
  };
}
