/**
 * File Name: mfa.services.ts
 * Description: Business rules for TOTP-based multi-factor authentication.
 * Author: Keefe Chen
 */

import {
  decryptSecret,
  encryptSecret,
} from "../../../services/encryption.service.js";
import {
  generateRecoveryCodes,
  generateTotpQrCode,
  generateTotpSecret,
  hashRecoveryCode,
  verifyTotpCode,
} from "../../../shared/utils/totp.util.js";

import { AppError } from "../../../shared/utils/AppError.js";
import {
  findUserById,
  findUserByIdWithMfaSecrets,
  saveUser,
} from "../auth.repository.js";

import type {
  MfaSetupResult,
  MfaStatus,
  VerifyMfaInput,
  DisableMfaInput,
} from "./mfa.types.js";

const SETUP_EXPIRY_MINUTES = 10;

const isEncryptionConfigured = (): boolean => {
  try {
    encryptSecret("probe");
    return true;
  } catch {
    return false;
  }
};

const requireConfigured = (): void => {
  if (!isEncryptionConfigured()) {
    throw new AppError(
      503,
      "MFA_NOT_CONFIGURED",
      "Multi-factor authentication is not configured on this server.",
    );
  }
};

const currentTotpStep = (): number => Math.floor(Date.now() / 1000 / 30);

export const mfaService = {
  /**
   * Returns the MFA status for the authenticated user.
   */
  async getStatus(userId: string): Promise<MfaStatus> {
    const user = await findUserById(userId);

    if (!user) {
      throw new AppError(404, "USER_NOT_FOUND", "User was not found.");
    }

    return {
      enabled: Boolean(user.mfaEnabled),
      enabledAt: user.mfaEnabledAt ?? null,
    };
  },

  /**
   * Begins enrollment by generating a pending secret and QR code.
   */
  async beginSetup(userId: string): Promise<MfaSetupResult> {
    requireConfigured();

    const user = await findUserByIdWithMfaSecrets(userId);

    if (!user) {
      throw new AppError(404, "USER_NOT_FOUND", "User was not found.");
    }

    if (user.mfaEnabled) {
      throw new AppError(
        409,
        "MFA_ALREADY_ENABLED",
        "Multi-factor authentication is already enabled.",
      );
    }

    const secret = generateTotpSecret();
    const encrypted = encryptSecret(secret);

    user.mfaPendingSecretEncrypted = encrypted;
    user.mfaPendingExpiresAt = new Date(
      Date.now() + SETUP_EXPIRY_MINUTES * 60 * 1000,
    );

    await saveUser(user);

    const qrCodeDataUrl = await generateTotpQrCode(user.email, secret);
    const manualEntryKey = secret;

    return {
      qrCodeDataUrl,
      manualEntryKey,
      expiresAt: user.mfaPendingExpiresAt,
    };
  },

  /**
   * Confirms enrollment using a valid TOTP code.
   */
  async verifySetup(
    userId: string,
    input: VerifyMfaInput,
  ): Promise<{ recoveryCodes: string[] }> {
    requireConfigured();

    const user = await findUserByIdWithMfaSecrets(userId);

    if (!user) {
      throw new AppError(404, "USER_NOT_FOUND", "User was not found.");
    }

    if (!user.mfaPendingSecretEncrypted) {
      throw new AppError(
        400,
        "MFA_SETUP_NOT_STARTED",
        "No MFA setup is in progress.",
      );
    }

    if (
      user.mfaPendingExpiresAt &&
      user.mfaPendingExpiresAt.getTime() < Date.now()
    ) {
      throw new AppError(
        410,
        "MFA_SETUP_EXPIRED",
        "The MFA setup has expired. Please start again.",
      );
    }

    const secret = decryptSecret(user.mfaPendingSecretEncrypted);

    if (!verifyTotpCode(secret, input.code)) {
      throw new AppError(
        400,
        "INVALID_MFA_CODE",
        "The verification code is invalid.",
      );
    }

    const recoveryCodes = generateRecoveryCodes();

    user.mfaEnabled = true;
    user.mfaSecretEncrypted = user.mfaPendingSecretEncrypted;
    user.mfaPendingSecretEncrypted = null;
    user.mfaPendingExpiresAt = null;
    user.mfaRecoveryCodeHashes = recoveryCodes.map(hashRecoveryCode);
    user.mfaLastUsedStep = currentTotpStep();
    user.mfaEnabledAt = new Date();

    await saveUser(user);

    return { recoveryCodes };
  },

  /**
   * Disables MFA after verifying a code.
   */
  async disable(userId: string, input: DisableMfaInput): Promise<void> {
    const user = await findUserByIdWithMfaSecrets(userId);

    if (!user) {
      throw new AppError(404, "USER_NOT_FOUND", "User was not found.");
    }

    if (!user.mfaEnabled || !user.mfaSecretEncrypted) {
      throw new AppError(
        409,
        "MFA_NOT_ENABLED",
        "Multi-factor authentication is not enabled.",
      );
    }

    const secret = decryptSecret(user.mfaSecretEncrypted);

    const isTotp = verifyTotpCode(secret, input.code);
    const isRecovery = user.mfaRecoveryCodeHashes?.includes(
      hashRecoveryCode(input.code),
    );

    if (!isTotp && !isRecovery) {
      throw new AppError(
        400,
        "INVALID_MFA_CODE",
        "The verification code is invalid.",
      );
    }

    user.mfaEnabled = false;
    user.mfaSecretEncrypted = null;
    user.mfaPendingSecretEncrypted = null;
    user.mfaPendingExpiresAt = null;
    user.mfaRecoveryCodeHashes = [];
    user.mfaLastUsedStep = null;
    user.mfaEnabledAt = null;

    await saveUser(user);
  },
};
