import { vi } from "vitest";

/**
 * Query result stub supporting the `.select()`/`.sort()`/`.exec()` chains
 * used by the model repositories.
 */
export const queryResult = (value: unknown) => ({
  select: vi.fn().mockReturnThis(),
  sort: vi.fn().mockReturnThis(),
  exec: vi.fn().mockResolvedValue(value),
});

/** Factory for the mocked `auth.model` module (`User` model). */
export const authModelMock = () => ({
  User: {
    findOne: vi.fn(),
    create: vi.fn(),
    findById: vi.fn(),
  },
});

/** Factory for the mocked `session.model` module (`AuthSession` model). */
export const sessionModelMock = () => ({
  AuthSession: {
    create: vi.fn(),
    findById: vi.fn(),
    find: vi.fn(),
    updateOne: vi.fn(),
    updateMany: vi.fn(),
  },
});
