import { createHmac } from 'node:crypto';

export function hashCitizen(identifier: string, pepper: string): string {
  const hmac = createHmac('sha256', pepper);
  hmac.update(identifier);
  return `hmac256:${hmac.digest('hex')}`;
}

export function getPepper(): string {
  const pepper = process.env.PEPPER?.trim();
  if (!pepper) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('PEPPER env var is required in production');
    }
    return 'dev-pepper-change-me';
  }
  return pepper;
}
