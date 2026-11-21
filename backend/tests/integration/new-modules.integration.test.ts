import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  assistant: {
    interpret: vi.fn(),
    clarify: vi.fn(),
    preview: vi.fn(),
    confirm: vi.fn(),
    cancel: vi.fn(),
    suggestions: vi.fn(),
  },
  notifications: {
    list: vi.fn(),
    unreadCount: vi.fn(),
    markAllRead: vi.fn(),
    clearAll: vi.fn(),
    getById: vi.fn(),
    markRead: vi.fn(),
    remove: vi.fn(),
    registerDevice: vi.fn(),
    unregisterDevice: vi.fn(),
    listDevices: vi.fn(),
  },
  preferences: {
    get: vi.fn(),
    update: vi.fn(),
    updateNotifications: vi.fn(),
    updateAppearance: vi.fn(),
    updateTimezone: vi.fn(),
  },
}));

vi.mock("../../src/modules/auth/auth.model.js", async () => {
  const { authModelMock } = await import("../helpers/authMocks.js");
  return authModelMock();
});
vi.mock("../../src/modules/auth/session.model.js", async () => {
  const { sessionModelMock } = await import("../helpers/authMocks.js");
  return sessionModelMock();
});
vi.mock("../../src/modules/assistant/assistant.service.js", () => ({
  assistantService: mocks.assistant,
}));
vi.mock("../../src/modules/notifications/notification.service.js", () => ({
  notificationService: mocks.notifications,
}));
vi.mock("../../src/modules/preferences/preference.service.js", () => ({
  preferenceService: mocks.preferences,
}));

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens";
import { queryResult } from "../helpers/authMocks.js";

const authenticate = (): string => {
  const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
  (
    User as never as { findById: ReturnType<typeof vi.fn> }
  ).findById.mockReturnValue(
    queryResult({ _id: "user-1", email: "ada@example.com", role: "user" }),
  );
  (
    AuthSession as never as { findById: ReturnType<typeof vi.fn> }
  ).findById.mockReturnValue(
    queryResult({
      _id: sessionId,
      userId: "user-1",
      revokedAt: null,
      expiresAt: new Date(Date.now() + 3_600_000),
      lastUsedAt: new Date(),
    }),
  );
  return token;
};

beforeEach(() => {
  vi.clearAllMocks();
  sessionCache.clear();
  mocks.assistant.interpret.mockResolvedValue({ draftId: "d-1" });
  mocks.assistant.clarify.mockResolvedValue({ draftId: "d-1" });
  mocks.assistant.preview.mockResolvedValue({ draft: {} });
  mocks.assistant.confirm.mockResolvedValue({ draftId: "d-1" });
  mocks.assistant.cancel.mockResolvedValue({ status: "cancelled" });
  mocks.assistant.suggestions.mockResolvedValue({ suggestions: ["Plan"] });
  mocks.notifications.list.mockResolvedValue({ items: [], pagination: {} });
  mocks.notifications.unreadCount.mockResolvedValue(0);
  mocks.notifications.markAllRead.mockResolvedValue(1);
  mocks.notifications.clearAll.mockResolvedValue(1);
  mocks.notifications.getById.mockResolvedValue({ _id: "n-1" });
  mocks.notifications.markRead.mockResolvedValue({ _id: "n-1" });
  mocks.notifications.remove.mockResolvedValue({ _id: "n-1" });
  mocks.notifications.registerDevice.mockResolvedValue({ _id: "dev-1" });
  mocks.notifications.unregisterDevice.mockResolvedValue({ _id: "dev-1" });
  mocks.notifications.listDevices.mockResolvedValue([]);
  mocks.preferences.get.mockResolvedValue({ locale: "en" });
  mocks.preferences.update.mockResolvedValue({ locale: "en" });
  mocks.preferences.updateNotifications.mockResolvedValue({});
  mocks.preferences.updateAppearance.mockResolvedValue({});
  mocks.preferences.updateTimezone.mockResolvedValue({});
});

describe("new module HTTP surfaces", () => {
  it("requires auth on every new endpoint", async () => {
    for (const path of [
      "/api/assistant/suggestions",
      "/api/notifications",
      "/api/preferences",
    ]) {
      const res = await request(app).get(path);
      expect(res.status).toBe(401);
    }
  });

  it("serves the assistant confirmation-gated flow", async () => {
    const token = authenticate();
    await request(app)
      .post("/api/assistant/interpret")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "Plan my week" })
      .expect(200);
    await request(app)
      .post("/api/assistant/clarify")
      .set("Authorization", `Bearer ${token}`)
      .send({ draftId: "d-1", message: "make it short" })
      .expect(200);
    await request(app)
      .post("/api/assistant/preview")
      .set("Authorization", `Bearer ${token}`)
      .send({ draftId: "d-1" })
      .expect(200);
    await request(app)
      .post("/api/assistant/confirm")
      .set("Authorization", `Bearer ${token}`)
      .send({ draftId: "d-1" })
      .expect(201);
    await request(app)
      .post("/api/assistant/cancel")
      .set("Authorization", `Bearer ${token}`)
      .send({ draftId: "d-1" })
      .expect(200);
    await request(app)
      .post("/api/assistant/suggestions")
      .set("Authorization", `Bearer ${token}`)
      .send({})
      .expect(200);
    expect(mocks.assistant.interpret).toHaveBeenCalledOnce();
    expect(mocks.assistant.confirm).toHaveBeenCalledOnce();
  });

  it("serves notification and device routes", async () => {
    const token = authenticate();
    await request(app)
      .get("/api/notifications")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .get("/api/notifications/unread-count")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .get("/api/notifications/n-1")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .patch("/api/notifications/n-1/read")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .patch("/api/notifications/read-all")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .delete("/api/notifications/n-1")
      .set("Authorization", `Bearer ${token}`)
      .expect(204);
    await request(app)
      .post("/api/notifications/devices")
      .set("Authorization", `Bearer ${token}`)
      .send({ token: "device-token", platform: "android" })
      .expect(201);
    await request(app)
      .get("/api/notifications/devices")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .delete("/api/notifications/devices/dev-1")
      .set("Authorization", `Bearer ${token}`)
      .expect(204);
    await request(app)
      .delete("/api/notifications")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    expect(mocks.notifications.list).toHaveBeenCalledOnce();
  });

  it("serves preference routes", async () => {
    const token = authenticate();
    await request(app)
      .get("/api/preferences")
      .set("Authorization", `Bearer ${token}`)
      .expect(200);
    await request(app)
      .patch("/api/preferences")
      .set("Authorization", `Bearer ${token}`)
      .send({ locale: "en" })
      .expect(200);
    await request(app)
      .patch("/api/preferences/notifications")
      .set("Authorization", `Bearer ${token}`)
      .send({ email: true })
      .expect(200);
    await request(app)
      .patch("/api/preferences/appearance")
      .set("Authorization", `Bearer ${token}`)
      .send({ theme: "dark" })
      .expect(200);
    await request(app)
      .patch("/api/preferences/timezone")
      .set("Authorization", `Bearer ${token}`)
      .send({ timezone: "UTC" })
      .expect(200);
    expect(mocks.preferences.updateTimezone).toHaveBeenCalledOnce();
  });
});
