/**
 * File Name: index.ts
 * Description: Public exports for the Rubrics module.
 * Author: Keefe Chen
 */

export { default as rubricRoutes } from "./rubric.routes.js";

export { rubricService, parseCriteria } from "./rubric.service.js";

export { rubricRepository } from "./rubric.repository.js";

export { Rubric, type RubricDocument } from "./rubric.model.js";

export type { RubricCriterion } from "./rubric.types.js";
