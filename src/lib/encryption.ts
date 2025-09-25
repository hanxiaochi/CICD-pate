import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // Recommended 12 bytes for GCM
const KEY_LENGTH = 32; // 256-bit key

function getEncryptionKey(): Buffer {
  const envKey = process.env.SSH_SECRET;
  if (envKey) {
    const keyBuf = Buffer.from(envKey, 'utf8');
    if (keyBuf.length === KEY_LENGTH) return keyBuf;
    if (keyBuf.length > KEY_LENGTH) return keyBuf.subarray(0, KEY_LENGTH);
    const padded = Buffer.alloc(KEY_LENGTH);
    keyBuf.copy(padded);
    return padded;
  }
  console.warn('SSH_SECRET not provided, using ephemeral encryption key. Encrypted data will not persist across restarts.');
  return crypto.randomBytes(KEY_LENGTH);
}

export function encryptCredential(plaintext: string): string {
  if (!plaintext || !plaintext.trim()) {
    throw new Error('Cannot encrypt empty or null credential');
  }
  try {
    const key = getEncryptionKey();
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, key, iv, { authTagLength: 16 });
    cipher.setAAD(Buffer.from('credential'));

    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();

    // Store as: base64(iv | tag | ciphertext) to simplify parsing
    const combined = Buffer.concat([iv, tag, encrypted]);
    return combined.toString('base64');
  } catch (err) {
    console.error('Encryption error:', err);
    throw new Error('Failed to encrypt credential');
  }
}

export function decryptCredential(encryptedBase64: string): string {
  if (!encryptedBase64 || !encryptedBase64.trim()) {
    throw new Error('Cannot decrypt empty or null encrypted data');
  }
  try {
    const key = getEncryptionKey();
    const combined = Buffer.from(encryptedBase64, 'base64');

    // Expect at least IV (12) + TAG (16) + 1 byte ciphertext
    if (combined.length <= IV_LENGTH + 16) {
      throw new Error('Invalid encrypted data format');
    }

    const iv = combined.subarray(0, IV_LENGTH);
    const tag = combined.subarray(IV_LENGTH, IV_LENGTH + 16);
    const ciphertext = combined.subarray(IV_LENGTH + 16);

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv, { authTagLength: 16 });
    decipher.setAAD(Buffer.from('credential'));
    decipher.setAuthTag(tag);

    const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
    return decrypted;
  } catch (err) {
    console.error('Decryption error:', err);
    throw new Error('Failed to decrypt credential - data may be corrupted or key mismatch');
  }
}