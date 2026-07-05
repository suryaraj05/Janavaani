import type { AuthUser } from '../middleware/auth.js';

export function isStaffRole(role: AuthUser['role']): boolean {
  return role === 'mp' || role === 'mp_staff';
}

/** Citizens may only read submissions tied to their citizen_hash. */
export function canReadSubmission(
  user: AuthUser,
  submissionCitizenHash: string | null | undefined,
  userCitizenHash: string,
): boolean {
  if (isStaffRole(user.role)) return true;
  return (
    submissionCitizenHash != null &&
    submissionCitizenHash.length > 0 &&
    submissionCitizenHash === userCitizenHash
  );
}
