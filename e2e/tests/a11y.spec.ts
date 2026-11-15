/**
 * File Name: a11y.spec.ts
 * Description: Accessibility scanning of the deployed web app using axe-core.
 * Fails on critical WCAG 2 A/AA violations; reports (does not fail on)
 * serious and moderate issues so the team can burn them down.
 */

import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

test.describe("accessibility", () => {
  test("app shell has no critical axe violations", async ({ page }) => {
    test.setTimeout(90_000);
    await page.goto("/", { waitUntil: "domcontentloaded" });
    // Give the Flutter engine a moment to paint before scanning the DOM.
    await page.waitForTimeout(3_000);

    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa"])
      .analyze();

    const critical = results.violations.filter((v) => v.impact === "critical");
    const serious = results.violations.filter((v) => v.impact === "serious");

    if (serious.length > 0) {
      console.warn(
        `serious (non-blocking) violations: ${serious
          .map((v) => v.id)
          .join(", ")}`,
      );
    }

    expect(
      critical,
      `critical violations: ${JSON.stringify(
        critical.map((v) => ({ id: v.id, nodes: v.nodes.length })),
        null,
        2,
      )}`,
    ).toEqual([]);
  });

  test("document has a language and a non-empty title", async ({ page }) => {
    await page.goto("/", { waitUntil: "domcontentloaded" });
    const lang = await page.locator("html").getAttribute("lang");
    expect(lang).toBeTruthy();
    await expect(page).toHaveTitle(/.+/);
  });
});
