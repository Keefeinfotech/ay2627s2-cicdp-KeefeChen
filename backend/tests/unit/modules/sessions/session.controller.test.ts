import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  create: vi.fn(),
  list: vi.fn(),
  get: vi.fn(),
  update: vi.fn(),
  join: vi.fn(),
  leave: vi.fn(),
  cancel: vi.fn(),
  complete: vi.fn(),
  delete: vi.fn(),
}));

vi.mock("../../../../src/modules/sessions/session.service.js", () => ({
  sessionService: mocks,
}));

vi.mock("../../../../src/modules/sessions/session.validation.js", () => ({
  createSessionSchema: { shape: { body: { parse: vi.fn((v: unknown) => v) } } },
  listSessionsSchema: { shape: { query: { parse: vi.fn((v: unknown) => v) } } },
  sessionParamSchema: {
    shape: { params: { parse: vi.fn((v: unknown) => v) } },
  },
  updateSessionSchema: {
    parse: vi.fn((v: any) => ({ params: v.params, body: v.body })),
  },
}));

import { sessionController } from "../../../../src/modules/sessions/session.controller.js";

const ok = () => ({
  status: vi.fn().mockReturnThis(),
  json: vi.fn().mockReturnThis(),
  send: vi.fn().mockReturnThis(),
});

describe("sessionController", () => {
  beforeEach(() => vi.clearAllMocks());

  it("rejects unauthenticated create", async () => {
    const res = ok();
    await sessionController.create(
      { params: { groupId: "g1" }, body: {} } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("rejects create without groupId", async () => {
    const res = ok();
    await sessionController.create(
      { userId: "u1", params: {}, body: {} } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("creates a session", async () => {
    mocks.create.mockResolvedValue({ _id: "s1" });
    const res = ok();
    await sessionController.create(
      {
        userId: "u1",
        params: { groupId: "g1" },
        body: { title: "T" },
      } as never,
      res as never,
      vi.fn() as never,
    );
    expect(mocks.create).toHaveBeenCalledWith("g1", "u1", { title: "T" });
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it("lists sessions", async () => {
    mocks.list.mockResolvedValue({
      items: [{ _id: "s1" }],
      pagination: { page: 1 },
    });
    const res = ok();
    await sessionController.list(
      { userId: "u1", params: { groupId: "g1" }, query: { page: 1 } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ data: [{ _id: "s1" }] }),
    );
  });

  it("gets a session", async () => {
    mocks.get.mockResolvedValue({ _id: "s1" });
    const res = ok();
    await sessionController.get(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(mocks.get).toHaveBeenCalledWith("g1", "u1", "s1");
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("updates a session", async () => {
    mocks.update.mockResolvedValue({ _id: "s1", title: "N" });
    const res = ok();
    await sessionController.update(
      {
        userId: "u1",
        params: { groupId: "g1", sessionId: "s1" },
        body: { title: "N" },
      } as never,
      res as never,
      vi.fn() as never,
    );
    expect(mocks.update).toHaveBeenCalledWith("g1", "u1", "s1", { title: "N" });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("joins a session", async () => {
    mocks.join.mockResolvedValue({ _id: "s1" });
    const res = ok();
    await sessionController.join(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("leaves a session", async () => {
    mocks.leave.mockResolvedValue({ _id: "s1" });
    const res = ok();
    await sessionController.leave(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("cancels a session", async () => {
    mocks.cancel.mockResolvedValue({ _id: "s1", status: "cancelled" });
    const res = ok();
    await sessionController.cancel(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("completes a session", async () => {
    mocks.complete.mockResolvedValue({ _id: "s1", status: "completed" });
    const res = ok();
    await sessionController.complete(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("removes a session", async () => {
    mocks.delete.mockResolvedValue(undefined);
    const res = ok();
    await sessionController.remove(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(mocks.delete).toHaveBeenCalledWith("g1", "u1", "s1");
    expect(res.status).toHaveBeenCalledWith(204);
  });

  it("forwards errors", async () => {
    const err = new Error("boom");
    mocks.get.mockRejectedValue(err);
    const next = vi.fn();
    await sessionController.get(
      { userId: "u1", params: { groupId: "g1", sessionId: "s1" } } as never,
      ok() as never,
      next as never,
    );
    expect(next).toHaveBeenCalledWith(err);
  });
});
