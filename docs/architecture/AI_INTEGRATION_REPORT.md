# AI Integration Report for Auxilia

## Objective
Propose how to integrate an AI component into the Auxilia web app (assistant capabilities) in an enterprise-appropriate way.

## Current State
- Backend: Express API with auth (JWT), security middleware (helmet, CORS, rate-limit), health endpoint
- Frontend: Flutter app with login/signup UI
- No AI/LLM integration yet

## Recommended Approach
### 1) Backend AI Service
Add `backend/src/services/aiService.ts` with provider abstraction:
- Support OpenAI, Azure OpenAI, or local models (Ollama) via env
- Use API keys from env (never commit) - reference via secret manager
- Add rate limiting per user/IP
- Add input validation/sanitization
- Log usage (tokens/cost) without PII

### 2) API Endpoints
- `POST /api/ai/chat` - authenticated (require JWT) - send message, get response
- `POST /api/ai/summarize` - summarize tasks/notes
- Add to Swagger

### 3) Security (Enterprise)
- Authentication required for AI endpoints
- Per-user rate limits + global limits
- Input length limits
- Content filtering/sanitization
- PII redaction before sending to third-party
- Audit logging
- Cost controls/quotas
- Use managed secrets (GitHub Secrets/Vault)

### 4) Frontend Integration
- Add AI chat screen in Flutter
- Stream responses if supported
- Show loading/error states
- Store history securely

### 5) Implementation Plan
1. Add deps: `openai` or `axios`
2. Create AI service + routes + middleware
3. Add env vars to `.env.example`
4. Add tests (mock provider)
5. Add UI screen
6. Update CI to scan deps

## Env Vars (example)
```
AI_PROVIDER=openai
AI_API_KEY=your_key_here
AI_MODEL=gpt-4o-mini
AI_MAX_TOKENS=512
AI_RATE_LIMIT_PER_USER=20
```

## Notes
- Start with mock provider for dev/testing
- Never log prompts/responses containing secrets
- Follow provider terms of service
- Consider on-prem/local models for sensitive data
