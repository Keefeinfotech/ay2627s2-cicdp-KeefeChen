import mongoose from "mongoose";
import { getMongoUri, isTest } from "./environment.js";

export const connectDatabase = async (): Promise<void> => {
  const mongoUri = getMongoUri();

  if (!mongoUri) {
    if (isTest()) {
      return;
    }

    throw new Error(
      "MONGODB_URI is not defined in environment variables"
    );
  }

  await mongoose.connect(mongoUri, {
    dbName: "auxilia",
    serverSelectionTimeoutMS: 5000,
  });

  console.log("[database] MongoDB connected");
  console.log(`[database] Database: ${mongoose.connection.name}`);
};

export const disconnectDatabase = async (): Promise<void> => {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.connection.close();
    console.log("[database] MongoDB connection closed");
  }
};
