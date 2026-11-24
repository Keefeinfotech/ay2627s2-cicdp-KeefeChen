import { describe, expect, it } from "vitest";
import {
  createEventValidation,
  getEventsQueryValidation,
  updateEventValidation,
} from "../../../../src/modules/calendar/calendar.validation.js";

const run = async (
  chains: any[],
  source: Record<string, unknown>,
  field: "body" | "query" | "params" = "body",
) => {
  const req: any = { body: {}, query: {}, params: {}, [field]: source };
  for (const chain of chains) await chain.run(req);
  const { validationResult } = await import("express-validator");
  return validationResult(req);
};

describe("calendar validation", () => {
  it("accepts valid create payload", async () => {
    const result = await run(createEventValidation, {
      title: "Meeting",
      startTime: "2026-01-01T10:00:00Z",
      endTime: "2026-01-01T11:00:00Z",
    });
    expect(result.isEmpty()).toBe(true);
  });

  it("rejects create with end before start", async () => {
    const result = await run(createEventValidation, {
      title: "Meeting",
      startTime: "2026-01-01T11:00:00Z",
      endTime: "2026-01-01T10:00:00Z",
    });
    expect(result.isEmpty()).toBe(false);
  });

  it("accepts valid update payload", async () => {
    const req: any = {
      body: { title: "N" },
      params: { id: "507f1f77bcf86cd799439011" },
      query: {},
    };
    for (const chain of updateEventValidation) await chain.run(req);
    const { validationResult } = await import("express-validator");
    expect(validationResult(req).isEmpty()).toBe(true);
  });

  it("rejects update with invalid id and bad endTime", async () => {
    const req: any = {
      body: {
        startTime: "2026-01-01T11:00:00Z",
        endTime: "2026-01-01T10:00:00Z",
      },
      params: { id: "bad" },
      query: {},
    };
    for (const chain of updateEventValidation) await chain.run(req);
    const { validationResult } = await import("express-validator");
    expect(validationResult(req).isEmpty()).toBe(false);
  });

  it("accepts valid get events query", async () => {
    const req: any = {
      query: {
        startDate: "2026-01-01T00:00:00Z",
        endDate: "2026-01-31T00:00:00Z",
      },
      body: {},
      params: {},
    };
    for (const chain of getEventsQueryValidation) await chain.run(req);
    const { validationResult } = await import("express-validator");
    expect(validationResult(req).isEmpty()).toBe(true);
  });
});
