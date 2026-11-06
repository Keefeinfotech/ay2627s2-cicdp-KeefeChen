import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/tasks/task.model.js", () => ({
  Task: {
    create: vi.fn(),
    findOne: vi.fn(),
    find: vi.fn(),
    countDocuments: vi.fn(),
    findOneAndUpdate: vi.fn(),
    updateOne: vi.fn(),
  },
}));

import { taskRepository } from "../../../../src/modules/tasks/task.repository.js";
import { CollationOptions, ExplainVerbosityLike, ObjectId, ReadPreferenceMode, ClientSession } from "mongodb";
import { Query, Document, DefaultSchemaOptions, _QueryFilter, Model, QueryOptions, Cursor, ProjectionType, UpdateQuery, ModifyResult, UpdateWithAggregationPipeline, ProjectionFields, AnyObject, IfEquals, IfAny, Require_id, AddDefaultId, SortOrder, UpdateWriteOpResult } from "mongoose";
import { TaskRecord } from "../../../../src/modules/tasks/task.types.js";

describe("task repository", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a task", async () => {
    const task = {
      _id: "task-1",
      toObject: () => ({ _id: "task-1", title: "Ship it" }),
    };
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.create).mockResolvedValue(task as any);

    const result = await taskRepository.create("user-1", { title: "Ship it" });

    expect(Task.create).toHaveBeenCalledWith({
      userId: "user-1",
      title: "Ship it",
      description: null,
      course: "",
      tags: [],
      groupId: null,
      assigneeId: null,
      assigneeName: null,
      reminderAt: null,
      priority: "medium",
      dueDate: null,
    });
    expect(result).toEqual({ _id: "task-1", title: "Ship it" });
  });

  it("finds a task for the user", async () => {
    const task = { _id: "task-1" };
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOne).mockReturnValue({
      lean: () => ({ exec: async () => task }),
    } as any);

    await expect(taskRepository.findByIdForUser("task-1", "user-1")).resolves.toBe(task);
  });

  it("lists tasks with pagination metadata", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.find).mockReturnValue({
      sort: () => ({
        skip: () => ({
          limit: () => ({ lean: () => ({ exec: async () => [{ _id: "task-1" }] }) }),
        }),
      }),
    } as any);
    vi.mocked(Task.countDocuments).mockReturnValue({
      exec: async () => 1,
      _mongooseOptions: undefined,
      $where: function (argument: string | Function): Query<(Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; })[], Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      all: function (path: string, val: Array<any>): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      allowDiskUse: function (value: boolean): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      and: function (array: _QueryFilter<{ [x: string]: any; }>[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      batchSize: function (val: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      box: function (lower: number[], upper: number[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      cast: function (model?: Model<any, {}, {}, {}, any, any, any> | null | undefined, obj?: any) {
        throw new Error("Function not implemented.");
      },
      catch: function <TResult = never>(onrejected?: ((reason: any) => TResult | PromiseLike<TResult>) | null | undefined): Promise<number | TResult> {
        throw new Error("Function not implemented.");
      },
      finally: function (onfinally?: (() => void) | null | undefined): Promise<number> {
        throw new Error("Function not implemented.");
      },
      circle: function (path: string, area: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      clone: function (): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      collation: function (value: CollationOptions): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      comment: function (val: string): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      countDocuments: function (criteria?: _QueryFilter<{ [x: string]: any; }> | undefined, options?: QueryOptions<TaskRecord> | undefined): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      cursor: function (options?: QueryOptions<TaskRecord> | undefined): Cursor<number, QueryOptions<TaskRecord>, number | null> {
        throw new Error("Function not implemented.");
      },
      deleteMany: function (filter?: _QueryFilter<{ [x: string]: any; }> | undefined, options?: QueryOptions<TaskRecord> | undefined): Query<any, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "deleteMany", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      deleteOne: function (filter?: _QueryFilter<{ [x: string]: any; }> | undefined, options?: QueryOptions<TaskRecord> | undefined): Query<any, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "deleteOne", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      distinct: function <DocKey extends string, ResultType = unknown>(field: DocKey, filter?: _QueryFilter<{ [x: string]: any; }> | undefined, options?: QueryOptions<TaskRecord> | undefined): Query<any[], Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "distinct", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      elemMatch: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      error: function (): NativeError | null {
        throw new Error("Function not implemented.");
      },
      equals: function (val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      estimatedDocumentCount: function (options?: QueryOptions<TaskRecord> | undefined): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "estimatedDocumentCount", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      exists: function (path: string, val: boolean): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      explain: function (verbose?: ExplainVerbosityLike): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      find: function (filter?: _QueryFilter<{ [x: string]: any; }> | undefined, projection?: ProjectionType<TaskRecord> | null | undefined, options?: QueryOptions<TaskRecord> | null | undefined): Query<(Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; })[], Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "find", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      findAndCount: function (): Promise<[number, number]> {
        throw new Error("Function not implemented.");
      },
      findOne: function (filter?: _QueryFilter<{ [x: string]: any; }> | undefined, projection?: ProjectionType<TaskRecord> | null | undefined, options?: QueryOptions<TaskRecord> | null | undefined): Query<(Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }) | null, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "findOne", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      findOneAndDelete: function (filter?: _QueryFilter<{ [x: string]: any; }> | undefined, options?: QueryOptions<TaskRecord> | null | undefined): Query<(Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }) | null, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "findOneAndDelete", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      findOneAndUpdate: function (filter: _QueryFilter<{ [x: string]: any; }>, update: UpdateQuery<TaskRecord>, options: QueryOptions<TaskRecord> & { includeResultMetadata: true; }): Query<ModifyResult<Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }>, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "findOneAndUpdate", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      findById: function (id: ObjectId | any, projection?: ProjectionType<TaskRecord> | null | undefined, options?: QueryOptions<TaskRecord> | null | undefined): Query<(Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }) | null, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "findOne", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      findByIdAndDelete: function (id: ObjectId | any, options: QueryOptions<TaskRecord> & { includeResultMetadata: true; }): Query<ModifyResult<Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }>, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "findOneAndDelete", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      findByIdAndUpdate: function (id: ObjectId | any, update: UpdateQuery<TaskRecord>, options: QueryOptions<TaskRecord> & { includeResultMetadata: true; }): Query<any, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "findOneAndUpdate", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      geometry: function (object: { type: string; coordinates: any[]; }): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      get: function (path: string) {
        throw new Error("Function not implemented.");
      },
      getFilter: function (): _QueryFilter<{ [x: string]: any; }> {
        throw new Error("Function not implemented.");
      },
      getOptions: function (): QueryOptions<TaskRecord> {
        throw new Error("Function not implemented.");
      },
      getPopulatedPaths: function (): Array<string> {
        throw new Error("Function not implemented.");
      },
      getQuery: function (): _QueryFilter<{ [x: string]: any; }> {
        throw new Error("Function not implemented.");
      },
      getUpdate: function (): UpdateWithAggregationPipeline | UpdateQuery<Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }> | null {
        throw new Error("Function not implemented.");
      },
      gt: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      gte: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      hint: function (val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      in: function (path: string, val: any[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      intersects: function (arg?: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      j: function (val: boolean | null): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      lean: function (): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      limit: function (val: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      lt: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      lte: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      transform: function <MappedType>(fn: (doc: number) => MappedType): Query<MappedType, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      maxDistance: function (path: string, val: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      maxTimeMS: function (ms: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      merge: function (source: _QueryFilter<{ [x: string]: any; }>): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      mod: function (path: string, val: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      model: undefined,
      mongooseOptions: function (val?: QueryOptions<TaskRecord> | undefined): QueryOptions<TaskRecord> {
        throw new Error("Function not implemented.");
      },
      ne: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      near: function (path: string, val: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      nin: function (path: string, val: any[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      nor: function (array: _QueryFilter<{ [x: string]: any; }>[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      or: function (array: _QueryFilter<{ [x: string]: any; }>[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      orFail: function (err?: NativeError | (() => NativeError)): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      polygon: function (path: string, ...coordinatePairs: number[][]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      populate: function (path: string | string[], select?: string | any, model?: string | Model<any, {}, {}, {}, any, any, any> | undefined, match?: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      pre: function (fn: Function): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      post: function (fn: Function): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      projection: function (fields?: string | ProjectionFields<Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }> | undefined): ProjectionFields<Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }> {
        throw new Error("Function not implemented.");
      },
      read: function (mode: string | ReadPreferenceMode, tags?: any[]): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      readConcern: function (level: string): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      regex: function (path: string, val: RegExp): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      replaceOne: function (filter?: _QueryFilter<{ [x: string]: any; }> | undefined, replacement?: (Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }) | AnyObject | undefined, options?: QueryOptions<TaskRecord> | null | undefined): Query<any, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "replaceOne", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      sanitizeProjection: function (value: boolean): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      schemaLevelProjections: function (value: boolean): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      select: function <RawDocTypeOverride extends { _id?: any; userId?: any; title?: any; description?: any; course?: any; status?: any; priority?: any; dueDate?: any; reminderAt?: any; completedAt?: any; deletedAt?: any; createdAt?: any; updatedAt?: any; } = {}>(arg: string | readonly string[] | Record<string, number | boolean | string | object>): Query<IfEquals<RawDocTypeOverride, {}, number, IfAny<RawDocTypeOverride, any, Document<unknown, {}, RawDocTypeOverride, {}, DefaultSchemaOptions> & Require_id<RawDocTypeOverride> & { __v: number; } & AddDefaultId<RawDocTypeOverride, {}, DefaultSchemaOptions>>>, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, IfEquals<RawDocTypeOverride, {}, TaskRecord, RawDocTypeOverride>, "countDocuments", {}, IfEquals<RawDocTypeOverride, {}, TaskRecord, RawDocTypeOverride>> {
        throw new Error("Function not implemented.");
      },
      selected: function (): boolean {
        throw new Error("Function not implemented.");
      },
      selectedExclusively: function (): boolean {
        throw new Error("Function not implemented.");
      },
      selectedInclusively: function (): boolean {
        throw new Error("Function not implemented.");
      },
      session: function (session: ClientSession | null): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      set: function (path: string | Record<string, unknown>, value?: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      setOptions: function (options: QueryOptions<TaskRecord>, overwrite?: boolean): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      setQuery: function (val: _QueryFilter<{ [x: string]: any; }> | null): void {
        throw new Error("Function not implemented.");
      },
      setUpdate: function (update: UpdateWithAggregationPipeline | UpdateQuery<TaskRecord>, cloneUpdate?: boolean): void {
        throw new Error("Function not implemented.");
      },
      size: function (path: string, val: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      skip: function (val: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      slice: function (path: string, val: number | Array<number>): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      sort: function (arg?: string | Record<string, SortOrder | { $meta: any; }> | [string, SortOrder][] | undefined | null, options?: { override?: boolean; }): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      tailable: function (bool?: boolean, opts?: { numberOfRetries?: number; tailableRetryInterval?: number; }): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      then: function <TResult1 = number, TResult2 = never>(onfulfilled?: ((value: number) => TResult1 | PromiseLike<TResult1>) | null | undefined, onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null | undefined): Promise<TResult1 | TResult2> {
        throw new Error("Function not implemented.");
      },
      toConstructor: function <RetType = Query>(): RetType {
        throw new Error("Function not implemented.");
      },
      updateMany: function (filter: _QueryFilter<{ [x: string]: any; }>, update: UpdateWithAggregationPipeline | UpdateQuery<TaskRecord>, options?: QueryOptions<TaskRecord> | null | undefined): Query<UpdateWriteOpResult, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "updateMany", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      updateOne: function (filter: _QueryFilter<{ [x: string]: any; }>, update: UpdateWithAggregationPipeline | UpdateQuery<TaskRecord>, options?: QueryOptions<TaskRecord> | null | undefined): Query<UpdateWriteOpResult, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "updateOne", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      w: function (val: string | number | null): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      where: function (path: string, val?: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      within: function (val?: any): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      wtimeout: function (ms: number): Query<number, Document<unknown, {}, TaskRecord, {}, DefaultSchemaOptions> & TaskRecord & Required<{ _id: string; }> & { __v: number; } & { id: string; }, {}, TaskRecord, "countDocuments", {}, TaskRecord> {
        throw new Error("Function not implemented.");
      },
      [Symbol.asyncIterator]: function (): AsyncIterableIterator<number> {
        throw new Error("Function not implemented.");
      },
      [Symbol.toStringTag]: ""
    });

    const result = await taskRepository.listForUser("user-1", { page: 2, limit: 20 });

    expect(result.type).toBe("offset");
    expect(result.items).toHaveLength(1);
    expect(result.pagination).toMatchObject({ page: 2, limit: 20, totalItems: 1 });
  });

  it("updates a task for the user", async () => {
    const task = { _id: "task-1" };
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOneAndUpdate).mockReturnValue({
      lean: () => ({ exec: async () => task }),
    } as any);

    await expect(
      taskRepository.updateForUser("task-1", "user-1", { status: "COMPLETED" })
    ).resolves.toBe(task);
  });

  it("soft deletes a task", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.updateOne).mockReturnValue({
      exec: async () => ({ modifiedCount: 1 }),
    });

    await expect(taskRepository.softDeleteForUser("task-1", "user-1")).resolves.toBe(
      true
    );
  });
});
