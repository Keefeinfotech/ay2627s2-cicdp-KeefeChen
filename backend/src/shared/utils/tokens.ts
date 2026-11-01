import { JWT_ISSUER } from "../../constants/security.js";
import { getJwtExpiresIn, getJwtSecret } from "../../config/environment.js";
import jwt, { type JwtPayload, type SignOptions } from "jsonwebtoken";
import { randomUUID } from "node:crypto";

export interface AccessTokenPayload extends JwtPayload {
  sub: string;
  email: string;
  jti: string;
}

export interface SignedAccessToken {
  token: string;
  sessionId: string;
}

export const signAccessToken = (
  userId: string,
  email: string,
  sessionId: string = randomUUID()
): SignedAccessToken => {
  const options = {
    subject: userId,
    jwtid: sessionId,
    expiresIn: getJwtExpiresIn(),
    issuer: JWT_ISSUER,
    algorithm: "HS256",
  } as SignOptions;

  const token = jwt.sign({ email }, getJwtSecret(), options);
  return { token, sessionId };
};

export const verifyAccessToken = (
  token: string
): AccessTokenPayload | null => {
  try {
    const payload = jwt.verify(token, getJwtSecret(), {
      issuer: JWT_ISSUER,
      algorithms: ["HS256"],
    });

    if (
      typeof payload === "string" ||
      typeof payload.sub !== "string" ||
      typeof payload.email !== "string" ||
      typeof payload.jti !== "string"
    ) {
      return null;
    }

    return payload as AccessTokenPayload;
  } catch {
    return null;
  }
};
