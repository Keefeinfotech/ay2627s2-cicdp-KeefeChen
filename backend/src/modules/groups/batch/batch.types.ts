/**
 * File Name: batch.types.ts
 * Description: Domain types for bulk group operations.
 * Author: Keefe Chen
 */
export interface BatchItemError {
  index: number;
  id?: string;
  code: string;
  message: string;
}

export interface BatchProcessResult {
  successful: string[];
  failed: BatchItemError[];
  totalProcessed: number;
}

export interface BatchAtomicResult {
  count: number;
}

export interface BatchAddMembersInput {
  memberIds: string[];
  atomic?: boolean;
}

export type BatchAddMembersDto = BatchAddMembersInput;
