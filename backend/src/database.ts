
/*
 * File Name: database.ts
 * Description: Connects the backend to MongoDB Atlas.
 * Author: Keefe Chen
 * Date: 27 October 2026
 */

import mongoose from "mongoose";

export async function connectDatabase(): Promise<void> {
  const mongoUri = process.env.MONGODB_URI;

  if (!mongoUri) {
    throw new Error("MONGODB_URI is not configured.");
  }

  await mongoose.connect(mongoUri);

  console.log("Connected to MongoDB Atlas.");
}
