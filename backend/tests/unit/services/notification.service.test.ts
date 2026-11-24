import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  info: vi.fn(),
  warn: vi.fn(),
}));

vi.mock("../../../src/config/logger.js", () => ({
  default: { info: mocks.info, warn: mocks.warn, error: vi.fn() },
}));

import { sendNotification } from "../../../src/services/notification.service.js";

describe("notification.service", () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    vi.clearAllMocks();
    delete process.env.NOTIFICATION_SERVICE_URL;
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it("skips when service url not configured", async () => {
    await expect(
      sendNotification({ to: "a@b.com", message: "hi" }),
    ).resolves.toBe(false);
    expect(mocks.info).toHaveBeenCalled();
  });

  it("posts notification and returns true on success", async () => {
    process.env.NOTIFICATION_SERVICE_URL = "http://notify.local/";
    global.fetch = vi.fn().mockResolvedValue({ ok: true }) as any;
    await expect(
      sendNotification({ to: "a@b.com", message: "hi", channel: "push" }),
    ).resolves.toBe(true);
    expect(global.fetch).toHaveBeenCalledWith(
      "http://notify.local/notify",
      expect.objectContaining({ method: "POST" }),
    );
  });

  it("returns false on non-ok response", async () => {
    process.env.NOTIFICATION_SERVICE_URL = "http://notify.local";
    global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500 }) as any;
    await expect(
      sendNotification({ to: "a@b.com", message: "hi" }),
    ).resolves.toBe(false);
    expect(mocks.warn).toHaveBeenCalled();
  });

  it("returns false when fetch throws", async () => {
    process.env.NOTIFICATION_SERVICE_URL = "http://notify.local";
    global.fetch = vi.fn().mockRejectedValue(new Error("down")) as any;
    await expect(
      sendNotification({ to: "a@b.com", message: "hi" }),
    ).resolves.toBe(false);
    expect(mocks.warn).toHaveBeenCalled();
  });
});
