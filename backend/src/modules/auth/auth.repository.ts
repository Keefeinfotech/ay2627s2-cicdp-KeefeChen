import { User, type IUser } from "./auth.model.js";

export const findUserByEmail = async (
  email: string,
  includePassword = false
): Promise<IUser | null> => {
  const query = User.findOne({ email: email.toLowerCase() });
  if (includePassword) query.select("+passwordHash");
  return query.exec();
};

export const findUserById = async (userId: string): Promise<IUser | null> =>
  User.findById(userId).exec();

export const findUserByIdWithMfaSecrets = async (
  userId: string,
): Promise<IUser | null> =>
  User.findById(userId)
    .select(
      "+mfaSecretEncrypted +mfaPendingSecretEncrypted +mfaRecoveryCodeHashes +mfaLastUsedStep",
    )
    .exec();

export const createUser = async (input: {
  name?: string;
  email: string;
  passwordHash: string;
}): Promise<IUser> => User.create(input);

export const saveUser = async (user: IUser): Promise<IUser> => user.save();

export const clearActiveSession = async (userId: string): Promise<void> => {
  await User.updateOne(
    { _id: userId },
    { $set: { activeSessionId: null, activeSessionExpiresAt: null } }
  ).exec();
};
