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

// Always log to stdout/stderr as well: in production the container's stdout
// is the only place platform logs (e.g. Render) can surface startup failures.
// Startup errors previously went exclusively to the file transports, so a
// crash during boot showed as a bare "Exited with status 1" with no reason.
logger.add(
  new winston.transports.Console({
    format:
      process.env.NODE_ENV === "production"
        ? winston.format.json()
        : winston.format.combine(
            winston.format.colorize(),
            winston.format.simple(),
          ),
  }),
);

export default logger;
