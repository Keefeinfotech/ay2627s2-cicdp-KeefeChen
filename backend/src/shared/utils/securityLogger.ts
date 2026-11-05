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

// Log a security event with structured data
export const logSecurityEvent = (
  event: string,
  details: Record<string, unknown> = {}
): void => {
  write("warn", {
    type: "security",
    event,
    ...details,
  });
};

export const logServerError = (
  details: Record<string, unknown> = {}
): void => {
  write("error", {
    type: "server_error",
    ...details,
  });
};

// Convenience functions for common security events
export const logAuthFailure = (event: string, ip?: string, userId?: string, requestId?: string, path?: string): void => {
  logSecurityEvent(event, {
    ip,
    userId,
    requestId,
    path,
    severity: "high",
    category: "authentication",
  });
};

export const logAccessDenied = (event: string, ip?: string, userId?: string, requestId?: string, path?: string, resource?: string): void => {
  logSecurityEvent(event, {
    ip,
    userId,
    requestId,
    path,
    severity: "medium",
    category: "access_control",
    resource,
  });
};

export const logRateLimitExceeded = (event: string, ip?: string, userId?: string, requestId?: string, path?: string): void => {
  logSecurityEvent(event, {
    ip,
    userId,
    requestId,
    path,
    severity: "medium",
    category: "rate_limiting",
  });
};

export const logSuspiciousActivity = (event: string, ip?: string, userId?: string, requestId?: string, path?: string, description?: string): void => {
  logSecurityEvent(event, {
    ip,
    userId,
    requestId,
    path,
    severity: "high",
    category: "suspicious_activity",
    description,
  });
};