export enum GroupVisibility {
  PRIVATE = "PRIVATE",
  PUBLIC = "PUBLIC",
}

export enum GroupStatus {
  ACTIVE = "ACTIVE",
  ARCHIVED = "ARCHIVED",
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