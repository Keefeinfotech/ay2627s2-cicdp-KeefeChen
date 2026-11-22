// Copy this file to <sequence>-<name>.mjs and implement both directions.
// Migrations are opt-in: they only run via `npm run migrate:up`.
//
// Every down() must be the exact inverse of up() and must be reviewed before a
// production rollback. Prefer additive changes; destructive down() steps need
// a verified backup (see scripts/backup-database.sh).
export const id = "0000-template";

export async function up(db) {
  // await db.collection("tasks").createIndex({ ownerId: 1, dueAt: 1 });
}

export async function down(db) {
  // await db.collection("tasks").dropIndex("ownerId_1_dueAt_1");
}
