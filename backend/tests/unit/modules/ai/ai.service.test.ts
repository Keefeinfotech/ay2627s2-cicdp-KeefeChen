import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { createChatReply } from "../../../../src/modules/ai/ai.service.js";

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
});
