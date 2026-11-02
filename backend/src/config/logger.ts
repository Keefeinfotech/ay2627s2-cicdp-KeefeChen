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
    winston.format.json()
  ),

  transports: [
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

// Display logs in terminal during development
if (process.env.NODE_ENV !== "production") {
  logger.add(
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    })
  );
}

export default logger;