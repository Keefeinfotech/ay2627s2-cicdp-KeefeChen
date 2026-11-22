// Minimal, reviewable migration runner for the MongoDB-backed API.
// Each migration is a .mjs file in scripts/migrations named <sequence>-<name>.mjs
// exporting `id`, `up(db)` and `down(db)`. Applied migrations are recorded in
// `migration_history`, so `down` is explicit and never guessed.
//
//   node scripts/migrate.mjs status
//   node scripts/migrate.mjs up
//   node scripts/migrate.mjs down 0002-add-task-index --confirm
import { readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import mongoose from "mongoose";

const migrationsDir = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "migrations",
);
const [command, target, confirm] = process.argv.slice(2);
const uri = process.env.MONGODB_URI;

function fail(message) {
  console.error(`migrate: ${message}`);
  process.exit(1);
}

if (!["up", "down", "status"].includes(command)) {
  fail(
    "usage: node scripts/migrate.mjs <up|down|status> [migration-id] [--confirm]",
  );
}
if (!uri) fail("MONGODB_URI is not set");
if (command === "down" && (!target || confirm !== "--confirm")) {
  fail(
    "down requires an explicit migration id and --confirm, e.g. down 0002-add-index --confirm",
  );
}

const fileNames = (await readdir(migrationsDir))
  .filter((name) => /^\d+[-_].*\.mjs$/.test(name))
  .sort();

const migrations = [];
for (const fileName of fileNames) {
  const module = await import(
    pathToFileURL(path.join(migrationsDir, fileName)).href
  );
  if (typeof module.up !== "function" || typeof module.down !== "function") {
    fail(`${fileName} must export up(db) and down(db)`);
  }
  migrations.push({ id: module.id ?? fileName.replace(/\.mjs$/, ""), module });
}

await mongoose.connect(uri);
try {
  const db = mongoose.connection.db;
  const history = db.collection("migration_history");
  const applied = new Map(
    (await history.find({}).toArray()).map((row) => [row.migrationId, row]),
  );

  if (command === "status") {
    for (const migration of migrations) {
      const state = applied.has(migration.id) ? "applied" : "pending";
      console.log(`${state.padEnd(8)} ${migration.id}`);
    }
  }

  if (command === "up") {
    for (const migration of migrations) {
      if (applied.has(migration.id)) continue;
      console.log(`Applying ${migration.id}...`);
      await migration.module.up(db);
      await history.updateOne(
        { migrationId: migration.id },
        { $set: { migrationId: migration.id, appliedAt: new Date() } },
        { upsert: true },
      );
      console.log(`Applied ${migration.id}.`);
    }
  }

  if (command === "down") {
    const migration = migrations.find((item) => item.id === target);
    if (!migration) throw new Error(`migrate: unknown migration id: ${target}`);
    if (!applied.has(migration.id)) {
      throw new Error(`migrate: ${migration.id} is not applied`);
    }
    console.log(`Reverting ${migration.id}...`);
    await migration.module.down(db);
    await history.deleteOne({ migrationId: migration.id });
    console.log(
      `Reverted ${migration.id}. Verify with migrate:status and the smoke suite.`,
    );
  }
} finally {
  await mongoose.disconnect();
}
