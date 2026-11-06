
/**
 * File Name: tasks.pact.test.ts
 * Description: Consumer-driven Pact contract tests for Auxilia task APIs.
 * Author: Keefe Chen
 *
 * Tests:
 * 1. Retrieve authenticated user's tasks.
 * 2. Create a new task.
 *
 * Framework:
 * - Pact JS V3
 * - Vitest
 *
 * Note:
 * These tests use a Pact mock server.
 * They generate consumer contracts that must subsequently
 * be verified against the actual Express.js backend.
 */

import { describe, expect, it } from "vitest";
import { PactV3, MatchersV3 } from "@pact-foundation/pact";

// ============================================================
// 1. PACT MATCHERS
// ============================================================

const { like, eachLike, string } = MatchersV3;

// ============================================================
// 2. PACT CONFIGURATION
// ============================================================

function createPact() {
  return new PactV3({
    consumer: "Auxilia-Frontend",
    provider: "Auxilia-API",
    dir: "pacts",
    logLevel: "warn",
  });
}

// API endpoint
const API_PATH = "/api/tasks";

// Test authentication token
const AUTH_TOKEN = "Bearer example-access-token";

// ============================================================
// 3. TASK API CONTRACT TESTS
// ============================================================

describe("Auxilia Task API Consumer Contract", () => {

  // ----------------------------------------------------------
  // TEST 1: GET TASKS
  // ----------------------------------------------------------

  it("should retrieve the authenticated user's tasks", async () => {
    const pact = createPact();

    pact
      .given("the authenticated user has at least one task")
      .uponReceiving(
        "a request to retrieve the current user's tasks"
      )
      .withRequest({
        method: "GET",
        path: API_PATH,
        headers: {
          Authorization: like(AUTH_TOKEN),
          Accept: "application/json",
        },
      })
      .willRespondWith({
        status: 200,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: like({
          success: true,
          data: eachLike({
            id: string("task-123"),
            title: string("Complete CI/CD assignment"),
            description: string("Finish the deployment report"),
            priority: string("high"),
            status: string("pending"),
          }),
        }),
      });

    await pact.executeTest(async (mockServer) => {

      // Send GET request to Pact mock server
      const response = await fetch(
        `${mockServer.url}${API_PATH}`,
        {
          method: "GET",
          headers: {
            Authorization: AUTH_TOKEN,
            Accept: "application/json",
          },
        }
      );

      // Verify HTTP status
      expect(response.status).toBe(200);

      // Parse response
      const payload = await response.json();

      // Verify response structure
      expect(payload.success).toBe(true);
      expect(Array.isArray(payload.data)).toBe(true);

      // Verify task properties
      expect(payload.data.length).toBeGreaterThan(0);

      expect(payload.data[0]).toEqual(
        expect.objectContaining({
          id: expect.any(String),
          title: expect.any(String),
          description: expect.any(String),
          priority: expect.any(String),
          status: expect.any(String),
        })
      );
    });
  });

  // ----------------------------------------------------------
  // TEST 2: CREATE TASK
  // ----------------------------------------------------------

  it("should create a task using the agreed request and response format", async () => {
    const pact = createPact();

    // Expected request body
    const requestBody = {
      title: "Complete CI/CD assignment",
      description: "Finish the deployment report",
      priority: "high",
      status: "pending",
    };

    pact
      .given("the authenticated user can create tasks")
      .uponReceiving(
        "a valid request to create a task"
      )
      .withRequest({
        method: "POST",
        path: API_PATH,
        headers: {
          Authorization: like(AUTH_TOKEN),
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: {
          title: string("Complete CI/CD assignment"),
          description: string("Finish the deployment report"),
          priority: string("high"),
          status: string("pending"),
        },
      })
      .willRespondWith({
        status: 201,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: like({
          success: true,
          data: {
            id: string("task-123"),
            title: string("Complete CI/CD assignment"),
            description: string("Finish the deployment report"),
            priority: string("high"),
            status: string("pending"),
          },
        }),
      });

    await pact.executeTest(async (mockServer) => {

      // Send POST request to Pact mock server
      const response = await fetch(
        `${mockServer.url}${API_PATH}`,
        {
          method: "POST",
          headers: {
            Authorization: AUTH_TOKEN,
            Accept: "application/json",
            "Content-Type": "application/json",
          },
          body: JSON.stringify(requestBody),
        }
      );

      // Verify HTTP status
      expect(response.status).toBe(201);

      // Parse response
      const payload = await response.json();

      // Verify response structure
      expect(payload.success).toBe(true);

      // Verify returned task properties
      expect(payload.data).toEqual(
        expect.objectContaining({
          id: expect.any(String),
          title: requestBody.title,
          description: requestBody.description,
          priority: requestBody.priority,
          status: requestBody.status,
        })
      );
    });
  });
});
