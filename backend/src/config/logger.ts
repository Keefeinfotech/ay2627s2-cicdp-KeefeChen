import winston from "winston";
import path from "path";

const logDirectory = path.resolve("logs");

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",

  format: winston.format.combine(
    winston.format.timestamp({
      format: "YYYY-MM-DD HH:mm:ss",
    }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),

  transports: [
    // Always write to stdout so Render/Docker capture startup and request
    // logs in their dashboards (12-factor). JSON keeps them machine-readable.
    new winston.transports.Console({
      format:
        process.env.NODE_ENV === "production"
          ? winston.format.json()
          : winston.format.combine(
              winston.format.colorize(),
              winston.format.simple(),
            ),
    }),

    // Store application errors
    new winston.transports.File({
      filename: path.join(logDirectory, "error.log"),
      level: "error",
    }),

    // Store all application logs
    new winston.transports.File({
      filename: path.join(logDirectory, "combined.log"),
    }),
  ],
});

export default logger;
