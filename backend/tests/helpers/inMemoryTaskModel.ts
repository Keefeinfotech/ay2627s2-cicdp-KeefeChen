/*
 * File Name: inMemoryTaskModel.ts
 * Description: Shared in-memory stand-in for the Mongoose `Task` model,
 *   used by the functional API tests and the Pact provider verification.
 *   It implements just enough of the model surface (create / find /
 *   findOne / countDocuments / findOneAndUpdate / updateOne) with
 *   Mongoose-style chainable queries so the whole HTTP pipeline can be
 *   exercised without a database.
 *
 *   Callers own the store: create one per test file with
 *   `vi.hoisted(() => ({ tasks: [] as Array<Record<string, any>> }))`
 *   and pass it to the factory inside the `vi.mock` factory.
 */

export interface InMemoryTaskStore {
  tasks: Array<Record<string, any>>;
}

const matchesFilter = (
  doc: Record<string, any>,
  filter: Record<string, any>,
): boolean => {
  for (const [key, condition] of Object.entries(filter)) {
    if (key === "$text") continue; // text search is not exercised here
    const value = doc[key] ?? null;
    if (
      condition !== null &&
      typeof condition === "object" &&
      !Array.isArray(condition) &&
      !(condition instanceof Date)
    ) {
      for (const [op, operand] of Object.entries(condition)) {
        if (op === "$eq") {
          if (value !== operand) return false;
          continue;
        }
        if (op === "$in") {
          if (!(operand as any[]).includes(value)) return false;
          continue;
        }
        const time = value instanceof Date ? value.getTime() : value;
        const operandTime =
          (operand as unknown) instanceof Date
            ? (operand as unknown as Date).getTime()
            : (operand as number);
        if (op === "$gte" && !(time >= operandTime)) return false;
        if (op === "$lte" && !(time <= operandTime)) return false;
        if (op === "$gt" && !(time > operandTime)) return false;
        if (op === "$lt" && !(time < operandTime)) return false;
        else if (!["$gte", "$lte", "$gt", "$lt"].includes(op)) return false;
      }
      continue;
    }
    if (condition instanceof Date) {
      const time = value instanceof Date ? value.getTime() : NaN;
      if (time !== condition.getTime()) return false;
      continue;
    }
    if (condition === null) {
      if (value !== null && value !== undefined) return false;
      continue;
    }
    if (value !== condition) return false;
  }
  return true;
};

const sortDocs = (
  docs: Array<Record<string, any>>,
  sort: Record<string, 1 | -1> | undefined,
): Array<Record<string, any>> => {
  if (!sort) return docs;
  const entries = Object.entries(sort);
  return [...docs].sort((a, b) => {
    for (const [field, direction] of entries) {
      const av = a[field] instanceof Date ? a[field].getTime() : a[field];
      const bv = b[field] instanceof Date ? b[field].getTime() : b[field];
      if (av === bv) continue;
      if (av === null || av === undefined) return 1;
      if (bv === null || bv === undefined) return -1;
      return direction * (av > bv ? 1 : -1);
    }
    return 0;
  });
};

/**
 * Builds the mocked `task.model.js` module. The store is injected so the
 * module factory stays pure (vi.mock factories run before test state is
 * initialised).
 */
export const createInMemoryTaskModel = (store: InMemoryTaskStore) => {
  const chainable = (resolve: () => any) => ({
    lean: () => chainable(resolve),
    exec: () => Promise.resolve().then(resolve),
  });

  return {
    __esModule: true,
    Task: {
      create: async (input: Record<string, any>) => {
        const { randomUUID } = await import("node:crypto");
        const now = new Date();
        const doc: Record<string, any> = {
          _id: input._id ?? randomUUID(),
          userId: input.userId,
          title: input.title,
          description: input.description ?? null,
          course: input.course ?? "",
          tags: input.tags ?? [],
          groupId: input.groupId ?? null,
          assigneeId: input.assigneeId ?? null,
          assigneeName: input.assigneeName ?? null,
          reminderAt: input.reminderAt ?? null,
          status: input.status ?? "todo",
          priority: input.priority ?? "medium",
          dueDate: input.dueDate ?? null,
          completedAt: input.completedAt ?? null,
          deletedAt: input.deletedAt ?? null,
          createdAt: now,
          updatedAt: now,
        };
        store.tasks.push(doc);
        const toObject = function (this: Record<string, any>) {
          const { toObject: _ignored, ...rest } = this;
          return { ...rest };
        };
        return { ...doc, toObject };
      },
      findOne: (filter: Record<string, any>) =>
        chainable(
          () => store.tasks.find((doc) => matchesFilter(doc, filter)) ?? null,
        ),
      find: (filter: Record<string, any>) => {
        let result = store.tasks.filter((doc) => matchesFilter(doc, filter));
        const query: any = {
          sort(sort: Record<string, 1 | -1>) {
            result = sortDocs(result, sort);
            return query;
          },
          skip(count: number) {
            result = result.slice(count);
            return query;
          },
          limit(count: number) {
            result = result.slice(0, count);
            return query;
          },
          lean: () => chainable(() => result),
        };
        return query;
      },
      countDocuments: (filter: Record<string, any>) =>
        chainable(
          () => store.tasks.filter((doc) => matchesFilter(doc, filter)).length,
        ),
      findOneAndUpdate: (
        filter: Record<string, any>,
        update: Record<string, any>,
        _opts?: Record<string, any>,
      ) =>
        chainable(() => {
          const doc = store.tasks.find((item) => matchesFilter(item, filter));
          if (!doc) return null;
          Object.assign(doc, update.$set ?? {});
          doc.updatedAt = new Date();
          return { ...doc };
        }),
      updateOne: (filter: Record<string, any>, update: Record<string, any>) =>
        chainable(() => {
          const doc = store.tasks.find((item) => matchesFilter(item, filter));
          if (!doc) return { modifiedCount: 0 };
          Object.assign(doc, update.$set ?? {});
          return { modifiedCount: 1 };
        }),
    },
  };
};
