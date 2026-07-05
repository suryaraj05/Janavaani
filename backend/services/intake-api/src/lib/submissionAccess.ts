import type { AuthUser } from '../middleware/auth.js';

export function isStaffRole(role: AuthUser['role']): boolean {
  return role === 'mp' || role === 'mp_staff';
}

/** Citizens may read their own submissions, or any ranked (clustered) public report. */
export function canReadSubmission(
  user: AuthUser,
  submissionCitizenHash: string | null | undefined,
  userCitizenHash: string,
  submissionData?: Record<string, unknown>,
): boolean {
  if (isStaffRole(user.role)) return true;
  if (
    submissionCitizenHash != null &&
    submissionCitizenHash.length > 0 &&
    submissionCitizenHash === userCitizenHash
  ) {
    return true;
  }
  // Public constituency feed — clustered reports are visible to all citizens.
  const clusterId = submissionData?.cluster_id as string | null | undefined;
  return clusterId != null && clusterId.length > 0;
}
