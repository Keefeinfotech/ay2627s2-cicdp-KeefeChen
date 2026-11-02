
/*
 * File Name: app.test.ts
 * Description: Tests the Express API health endpoint.
 * Author: Keefe Chen
 * Date: 27 October 2026
 */

import { describe, expect, it } from "vitest";
import request from "supertest";
import app from "../src/app.js";

describe("GET /api/health", () => {
  it("returns HTTP 200 when the API is healthy", async () => {
    const response = await request(app).get("/api/health");

    expect(response.status).toBe(200);
    expect(response.body.status).toBe("ok");
    expect(response.body.service).toBe("personal-secretary-api");
  });
});
