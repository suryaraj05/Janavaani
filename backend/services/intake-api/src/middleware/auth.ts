import type { Request, Response, NextFunction } from 'express';
import { admin, getDb } from '../firebase.js';

export interface AuthUser {
  uid: string;
  email?: string;
  role: 'citizen' | 'mp_staff' | 'mp';
  displayName?: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing authorization token' });
    return;
  }

  const token = header.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const userDoc = await getDb().collection('users').doc(decoded.uid).get();
    const data = userDoc.data();

    req.user = {
      uid: decoded.uid,
      email: decoded.email,
      role: (data?.role as AuthUser['role']) ?? 'citizen',
      displayName: data?.displayName as string | undefined,
    };
    next();
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
  }
}

export function requireRole(...roles: AuthUser['role'][]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Insufficient permissions' });
      return;
    }
    next();
  };
}
