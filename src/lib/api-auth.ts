import { timingSafeEqual } from 'crypto';

function constantTimeEqual(actual: string, expected: string): boolean {
  const actualBuffer = Buffer.from(actual);
  const expectedBuffer = Buffer.from(expected);
  return (
    actualBuffer.length === expectedBuffer.length &&
    timingSafeEqual(actualBuffer, expectedBuffer)
  );
}

export function hasValidApiToken(request: Request): boolean {
  const configuredToken = process.env.CICD_API_TOKEN?.trim();
  const authorization = request.headers.get('authorization');
  const providedToken = authorization?.startsWith('Bearer ')
    ? authorization.slice(7).trim()
    : '';

  return Boolean(
    configuredToken &&
      providedToken &&
      constantTimeEqual(providedToken, configuredToken)
  );
}

export function requireApiToken(request: Request): void {
  if (
    !hasValidApiToken(request)
  ) {
    throw new Error('Unauthorized');
  }
}

export function credentialsMatch(
  actualUsername: string,
  actualPassword: string,
): boolean {
  const expectedUsername = process.env.CICD_ADMIN_USERNAME?.trim();
  const expectedPassword = process.env.CICD_ADMIN_PASSWORD;

  return Boolean(
    expectedUsername &&
      expectedPassword &&
      constantTimeEqual(actualUsername, expectedUsername) &&
      constantTimeEqual(actualPassword, expectedPassword),
  );
}
