export interface MfaSetupResult {
  qrCodeDataUrl: string;
  manualEntryKey: string;
  expiresAt: Date;
}

export interface VerifyMfaInput {
  code: string;
}

export interface DisableMfaInput {
  code: string;
}

export interface MfaStatus {
  enabled: boolean;
  enabledAt: Date | null;
}

export interface MfaChallengeResult {
  requiresMfa: true;
  challengeToken: string;
}

export interface MfaLoginResult {
  token: string;
  user: {
    id: string;
    name?: string;
    email: string;
  };
}