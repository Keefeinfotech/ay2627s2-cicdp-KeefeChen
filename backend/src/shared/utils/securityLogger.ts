const write = (
  level: "warn" | "error",
  payload: Record<string, unknown>
): void => {
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    ...payload,
  });

  if (level === "error") {
    console.error(line);
  } else {
    console.warn(line);
  }
};

export const logSecurityEvent = (
  event: string,
  details: Record<string, unknown> = {}
): void => {
  write("warn", { type: "security", event, ...details });
};

export const logServerError = (
  details: Record<string, unknown> = {}
): void => {
  write("error", { type: "server_error", ...details });
};
