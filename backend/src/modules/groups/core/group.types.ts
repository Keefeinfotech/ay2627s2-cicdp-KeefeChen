/**
 * File Name: group.types.ts
 * Description: Data transfer objects, enums, and request types for groups.
 * Author: Keefe Chen
 */

import { Request } from "express";

export enum GroupVisibility {
  PRIVATE = "PRIVATE",
  PUBLIC = "PUBLIC",
}

export enum GroupStatus {
  ACTIVE = "ACTIVE",
  ARCHIVED = "ARCHIVED",
}

export enum MemberStatus {
  ACTIVE = "ACTIVE",
  LEFT = "LEFT",
  REMOVED = "REMOVED",
}

export enum GroupRole {
  OWNER = "OWNER",
  ADMIN = "ADMIN",
  MEMBER = "MEMBER",
}

export interface CreateGroupInput {
  name: string;
  description?: string;
  visibility?: GroupVisibility;
}

export interface UpdateGroupInput {
  name?: string;
  description?: string;
  visibility?: GroupVisibility;
}

export interface GroupListQuery {
  page: number;
  limit: number;
  search?: string;
}

export interface AuthenticatedUser {
  id: string;
  email?: string;
  [key: string]: unknown;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthenticatedUser;
}