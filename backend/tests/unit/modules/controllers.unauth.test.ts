import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../src/modules/sessions/session.service.js", () => ({
  sessionService: {},
}));
vi.mock("../../../src/modules/sessions/session.validation.js", () => ({
  createSessionSchema: { shape: { body: { parse: (v: any) => v } } },
  listSessionsSchema: { shape: { query: { parse: (v: any) => v } } },
  sessionParamSchema: { shape: { params: { parse: (v: any) => v } } },
  updateSessionSchema: {
    parse: (v: any) => ({ params: v.params, body: v.body }),
  },
}));
vi.mock("../../../src/modules/rubrics/rubric.service.js", () => ({
  rubricService: {},
}));
vi.mock("../../../src/modules/rubrics/rubric.validation.js", () => ({
  parseRubricSchema: { shape: { body: { parse: (v: any) => v } } },
  listRubricsSchema: { shape: { query: { parse: (v: any) => v } } },
  rubricParamSchema: { shape: { params: { parse: (v: any) => v } } },
  rubricRoadmapProposalSchema: { shape: { params: { parse: (v: any) => v } } },
}));

import { sessionController } from "../../../src/modules/sessions/session.controller.js";
import { rubricController } from "../../../src/modules/rubrics/rubric.controller.js";

const res = () => ({
  status: vi.fn().mockReturnThis(),
  json: vi.fn().mockReturnThis(),
  send: vi.fn().mockReturnThis(),
});
const run = async (fn: any, req: any) => {
  const r: any = res();
  const next = vi.fn();
  await fn(req, r, next);
  return { r, next };
};

describe("controller unauth branches", () => {
  beforeEach(() => vi.clearAllMocks());

  it("session handlers reject unauth", async () => {
    for (const [fn, req] of [
      [sessionController.list, { params: { groupId: "g1" }, query: {} }],
      [sessionController.get, { params: { groupId: "g1", sessionId: "s1" } }],
      [
        sessionController.update,
        { params: { groupId: "g1", sessionId: "s1" }, body: {} },
      ],
      [sessionController.join, { params: { groupId: "g1", sessionId: "s1" } }],
      [sessionController.leave, { params: { groupId: "g1", sessionId: "s1" } }],
      [
        sessionController.cancel,
        { params: { groupId: "g1", sessionId: "s1" } },
      ],
      [
        sessionController.complete,
        { params: { groupId: "g1", sessionId: "s1" } },
      ],
      [
        sessionController.remove,
        { params: { groupId: "g1", sessionId: "s1" } },
      ],
    ] as any[]) {
      const { r } = await run(fn, req);
      expect(r.status).toHaveBeenCalledWith(401);
    }
  });

  it("rubric handlers reject unauth", async () => {
    for (const [fn, req] of [
      [rubricController.list, { params: { groupId: "g1" }, query: {} }],
      [rubricController.get, { params: { groupId: "g1", rubricId: "r1" } }],
      [
        rubricController.createRoadmapProposal,
        { params: { groupId: "g1", rubricId: "r1" } },
      ],
      [rubricController.remove, { params: { groupId: "g1", rubricId: "r1" } }],
    ] as any[]) {
      const { r } = await run(fn, req);
      expect(r.status).toHaveBeenCalledWith(401);
    }
  });
});
