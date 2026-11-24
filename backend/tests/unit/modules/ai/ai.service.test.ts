import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { createChatReply, createTaskDraft } from "../../../../src/modules/ai/ai.service.js";

const originalEnv = { ...process.env };

const setAiEnv = (values: Record<string, string | undefined>) => {
  for (const key of Object.keys(process.env)) {
    if (key.startsWith("AI_")) delete process.env[key];
  }
  for (const [key, value] of Object.entries(values)) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }
};

const jsonResponse = (status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

describe("ai service", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    vi.unstubAllGlobals();
  });

  it("returns a clearly labelled mock reply by default", async () => {
    setAiEnv({ AI_PROVIDER: undefined, AI_MODEL: undefined });

    const reply = await createChatReply("hello");

    expect(reply.provider).toBe("mock");
    expect(reply.reply).toContain("Auxilia AI (mock)");
  });

  it("rejects unsupported providers", async () => {
    setAiEnv({ AI_PROVIDER: "made-up", AI_MODEL: "x" });

    await expect(createChatReply("hello")).rejects.toMatchObject({
      status: 501,
      code: "AI_PROVIDER_UNSUPPORTED",
    });
  });

  it("requires an API key for a real provider", async () => {
    setAiEnv({ AI_PROVIDER: "openai-compatible", AI_API_KEY: undefined });

    await expect(createChatReply("hello")).rejects.toMatchObject({
      status: 503,
      code: "AI_PROVIDER_NOT_CONFIGURED",
    });
  });

  it("calls an OpenAI-compatible endpoint and returns the first choice", async () => {
    setAiEnv({
      AI_PROVIDER: "openai-compatible",
      AI_API_KEY: "test-key",
      AI_BASE_URL: "https://ai.example.test/v1/",
      AI_MODEL: "study-model",
      AI_MAX_TOKENS: "128",
    });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(200, {
        choices: [{ message: { content: "Start with the weakest topic." } }],
      }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const reply = await createChatReply("plan my revision");

    expect(reply).toEqual({
      reply: "Start with the weakest topic.",
      provider: "openai-compatible",
      model: "study-model",
    });
    expect(fetchMock).toHaveBeenCalledWith(
      "https://ai.example.test/v1/chat/completions",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Bearer test-key",
        }),
      }),
    );
    const body = JSON.parse(String(fetchMock.mock.calls[0][1]?.body));
    expect(body.max_tokens).toBe(128);
    expect(body.messages.at(-1)).toEqual({
      role: "user",
      content: "plan my revision",
    });
  });

  it("maps provider 429 responses to a safe 502", async () => {
    setAiEnv({
      AI_PROVIDER: "openai-compatible",
      AI_API_KEY: "test-key",
      AI_BASE_URL: "https://ai.example.test/v1",
      AI_MODEL: "study-model",
    });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(jsonResponse(429, { error: "quota" })),
    );

    await expect(createChatReply("hello")).rejects.toMatchObject({
      status: 502,
      code: "AI_PROVIDER_RATE_LIMITED",
    });
  });

  it("rejects an empty provider reply", async () => {
    setAiEnv({
      AI_PROVIDER: "openai-compatible",
      AI_API_KEY: "test-key",
      AI_BASE_URL: "https://ai.example.test/v1",
      AI_MODEL: "study-model",
    });
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(jsonResponse(200, { choices: [] })),
    );

    await expect(createChatReply("hello")).rejects.toMatchObject({
      status: 502,
      code: "AI_PROVIDER_EMPTY_REPLY",
    });
  });

  it("creates a mock task draft with date, priority and course", async () => {
    setAiEnv({ AI_PROVIDER: "mock" });
    const result = await createTaskDraft(
      "Create a high priority task tomorrow to study for course CS101",
      [],
      { currentDate: "2026-11-24" },
    );
    expect(result.draft).toMatchObject({
      priority: "high",
      course: "CS101",
      dueDate: "2026-11-25",
    });
    expect(result.clarification).toBeNull();
  });

  it("asks for clarification on ambiguous date in mock draft", async () => {
    setAiEnv({ AI_PROVIDER: "mock" });
    const result = await createTaskDraft("submit report 3/4", [], {
      currentDate: "2026-11-24",
    });
    expect(result.draft).toBeNull();
    expect(result.clarification).toMatch(/clarify/i);
  });

  it("asks for a title when mock draft has no usable title", async () => {
    setAiEnv({ AI_PROVIDER: "mock" });
    const result = await createTaskDraft("task tomorrow", [], {
      currentDate: "2026-11-24",
    });
    expect(result.draft).toBeNull();
    expect(result.clarification).toMatch(/title/i);
  });

  it("parses weekday and month-name dates in mock drafts", async () => {
    setAiEnv({ AI_PROVIDER: "mock" });
    const weekday = await createTaskDraft("Submit essay Friday", [], {
      currentDate: "2026-11-24", // Tuesday
    });
    expect(weekday.draft?.dueDate).toBe("2026-11-27");

    const named = await createTaskDraft("Pay fees 5 Dec 2026", [], {
      currentDate: "2026-11-24",
    });
    expect(named.draft?.dueDate).toBe("2026-12-05");
  });

  it("handles mock draft clarification follow-up context", async () => {
    setAiEnv({ AI_PROVIDER: "mock" });
    const result = await createTaskDraft(
      "tomorrow",
      [
        { role: "user", content: "submit report 3/4" },
        { role: "assistant", content: "Which date format did you mean? Please clarify the deadline." },
      ],
      { currentDate: "2026-11-24" },
    );
    expect(result.draft?.dueDate).toBe("2026-11-25");
    expect(result.draft?.title).toMatch(/Submit report/i);
  });

  it("rejects unsupported provider for task drafts", async () => {
    setAiEnv({ AI_PROVIDER: "made-up", AI_API_KEY: "x" });
    await expect(createTaskDraft("hello")).rejects.toMatchObject({
      status: 501,
      code: "AI_PROVIDER_UNSUPPORTED",
    });
  });

  it("requires API key for real-provider task drafts", async () => {
    setAiEnv({ AI_PROVIDER: "openai-compatible", AI_API_KEY: undefined });
    await expect(createTaskDraft("hello")).rejects.toMatchObject({
      status: 503,
      code: "AI_PROVIDER_NOT_CONFIGURED",
    });
  });
});
