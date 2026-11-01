import { getAiModel, getAiProvider } from "../../config/environment.js";
import { AppError } from "../../shared/utils/AppError.js";

export interface ChatReply {
  reply: string;
  provider: string;
  model: string;
}

export const createChatReply = (message: string): ChatReply => {
  const provider = getAiProvider();
  const model = getAiModel();

  if (provider === "mock") {
    return {
      reply: `Auxilia AI (mock): I received your message: "${message}". Configure AI_PROVIDER and API keys for real responses.`,
      provider,
      model,
    };
  }

  throw new AppError(501, "NOT_IMPLEMENTED", "AI provider is not implemented");
};
