import { Request } from "express";
import { ClientSession, Document, Types } from "mongoose";

export enum GroupRole {
  OWNER = "OWNER",
  ADMIN = "ADMIN",
  MEMBER = "MEMBER",
}

export enum MemberStatus {
  ACTIVE = "ACTIVE",
  PENDING = "PENDING",
  REJECTED = "REJECTED",
  LEFT = "LEFT",
}

export interface IMember {
  _id?: Types.ObjectId;
  groupId: Types.ObjectId | string;
  userId: Types.ObjectId | string;
  role: GroupRole;
  status: MemberStatus;
  joinedAt?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

export interface IMemberDocument extends Document, Omit<IMember, "_id"> {}

export interface CreateMemberInput {
  groupId: string;
  userId: string;
  role?: GroupRole;
  status?: MemberStatus;
}

export interface UpdateMemberRoleInput {
  role: GroupRole;
}

export interface AuthenticatedUser {
  id: string;
  email?: string;
  [key: string]: unknown;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthenticatedUser;
}