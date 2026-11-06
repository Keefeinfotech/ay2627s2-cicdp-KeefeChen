/**
 * File Name: ai.service.ts
 * Description: Provider-backed chat replies for the assistant. The mock
 * provider stays available for local development and CI; any other provider is
 * served by an OpenAI-compatible chat completions endpoint.
 * Author: Keefe Chen
 */

import {
  getAiApiKey,
  getAiBaseUrl,
  getAiMaxTokens,
  getAiModel,
  getAiProvider,
  getAiTimeoutMs,
} from "../../config/environment.js";
import logger from "../../config/logger.js";
import { AppError } from "../../shared/utils/AppError.js";

export interface ChatReply {
  reply: string;
  provider: string;
  model: string;
}

interface OpenAiCompatibleResponse {
  choices?: Array<{
    message?: {
      content?: string | null;
    };
  }>;
}

const SYSTEM_PROMPT =
  "You are Auxilia, a concise study-planning assistant. Help the student " +
  "plan, prioritise and break down academic work. Do not claim to submit " +
  "work for the student. If you are unsure, say so and suggest a small next " +
  "step.";

const mockReply = (message: string, provider: string, model: string): ChatReply => ({
  reply:
    `Auxilia AI (mock): I received your message: "${message}". ` +
    "Configure AI_PROVIDER and AI_API_KEY for real responses.",
  provider,
  model,
});

const providerError = (
  status: number,
  code: string,
  fallback: string,
): AppError =>
  new AppError(502, code, fallback, { providerStatus: status });

export const createChatReply = async (
  message: string,
): Promise<ChatReply> => {
  const provider = getAiProvider();
  const model = getAiModel();

  if (provider === "mock") {
    logger.info("ai.chat.mock", { messageLength: message.length, provider, model });
    return mockReply(message, provider, model);
  }

  if (provider !== "openai" && provider !== "openai-compatible") {
    throw new AppError(
      501,
      "AI_PROVIDER_UNSUPPORTED",
      `AI provider "${provider}" is not supported. Use mock or openai-compatible.`,
    );
  }

  const apiKey = getAiApiKey();
  if (!apiKey) {
    throw new AppError(
      503,
      "AI_PROVIDER_NOT_CONFIGURED",
      "The AI provider is not configured.",
    );
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), getAiTimeoutMs());

  try {
    logger.info("ai.chat.request", {
      provider,
      model,
      messageLength: message.length,
    });

    const response = await fetch(`${getAiBaseUrl()}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        max_tokens: getAiMaxTokens(),
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: message },
        ],
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const code =
        response.status === 401 || response.status === 403
          ? "AI_PROVIDER_AUTH_FAILED"
          : response.status === 429
            ? "AI_PROVIDER_RATE_LIMITED"
            : "AI_PROVIDER_REJECTED";
      logger.warn("ai.chat.provider_error", {
        provider,
        model,
        status: response.status,
        code,
      });
      throw providerError(
        response.status,
        code,
        "The AI provider could not complete the request.",
      );
    }

    const payload = (await response.json()) as OpenAiCompatibleResponse;
    const reply = payload.choices?.[0]?.message?.content?.trim();
    if (!reply) {
      throw new AppError(
        502,
        "AI_PROVIDER_EMPTY_REPLY",
        "The AI provider returned an empty reply.",
      );
    }

    logger.info("ai.chat.completed", {
      provider,
      model,
      replyLength: reply.length,
    });
    return { reply, provider, model };
  } catch (error) {
    if (error instanceof AppError) throw error;
    if (error instanceof Error && error.name === "AbortError") {
      throw new AppError(
        504,
        "AI_PROVIDER_TIMEOUT",
        "The AI provider took too long to respond.",
      );
    }
    logger.error("ai.chat.provider_failure", {
      provider,
      model,
      message: error instanceof Error ? error.message : String(error),
    });
    throw new AppError(
      502,
      "AI_PROVIDER_UNAVAILABLE",
      "The AI provider is unavailable.",
    );
  } finally {
    clearTimeout(timeout);
  }
};
