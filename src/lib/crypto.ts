import { createHash, randomBytes, createCipheriv, createDecipheriv } from 'crypto';

interface EncryptionPayload {
  ciphertext: string;
  iv: string;
  tag: string;
}

interface StoredSecret {
  v: number;
  iv: string;
  tag: string;
  ct: string;
}

class CryptoError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = 'CryptoError';
  }
}

function getEncryptionKey(): Buffer {
  const encryptionKey = process.env.ENCRYPTION_KEY;
  
  if (!encryptionKey) {
    throw new CryptoError('ENCRYPTION_KEY environment variable is required', 'MISSING_ENCRYPTION_KEY');
  }

  try {
    // Try to parse as hex first
    if (/^[0-9a-fA-F]+$/.test(encryptionKey)) {
      const keyBuffer = Buffer.from(encryptionKey, 'hex');
      if (keyBuffer.length === 32) {
        return keyBuffer;
      }
      // If hex but not 32 bytes, derive key
      return createHash('sha256').update(keyBuffer).digest();
    }

    // Try to parse as base64
    try {
      const keyBuffer = Buffer.from(encryptionKey, 'base64');
      if (keyBuffer.length === 32) {
        return keyBuffer;
      }
      // If base64 but not 32 bytes, derive key
      return createHash('sha256').update(keyBuffer).digest();
    } catch {
      // If not valid base64, treat as string and derive key
      return createHash('sha256').update(encryptionKey, 'utf8').digest();
    }
  } catch (error) {
    throw new CryptoError('Failed to process ENCRYPTION_KEY', 'INVALID_ENCRYPTION_KEY');
  }
}

export function encrypt(text: string): EncryptionPayload {
  if (!text || typeof text !== 'string') {
    throw new CryptoError('Text to encrypt must be a non-empty string', 'INVALID_INPUT');
  }

  try {
    const key = getEncryptionKey();
    const iv = randomBytes(12); // 96-bit IV for GCM
    const cipher = createCipheriv('aes-256-gcm', key, iv);
    
    let ciphertext = cipher.update(text, 'utf8', 'hex');
    ciphertext += cipher.final('hex');
    
    const tag = cipher.getAuthTag();

    return {
      ciphertext,
      iv: iv.toString('hex'),
      tag: tag.toString('hex')
    };
  } catch (error) {
    if (error instanceof CryptoError) {
      throw error;
    }
    throw new CryptoError('Encryption failed: ' + (error as Error).message, 'ENCRYPTION_FAILED');
  }
}

export function decrypt(payload: EncryptionPayload): string {
  if (!payload || typeof payload !== 'object') {
    throw new CryptoError('Payload must be an object with ciphertext, iv, and tag', 'INVALID_PAYLOAD');
  }

  const { ciphertext, iv, tag } = payload;

  if (!ciphertext || !iv || !tag) {
    throw new CryptoError('Payload must contain ciphertext, iv, and tag', 'INCOMPLETE_PAYLOAD');
  }

  try {
    const key = getEncryptionKey();
    const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'hex'));
    
    decipher.setAuthTag(Buffer.from(tag, 'hex'));
    
    let plaintext = decipher.update(ciphertext, 'hex', 'utf8');
    plaintext += decipher.final('utf8');
    
    return plaintext;
  } catch (error) {
    if (error instanceof CryptoError) {
      throw error;
    }
    
    // Check for authentication failure
    if ((error as Error).message.includes('auth') || (error as Error).message.includes('tag')) {
      throw new CryptoError('Decryption failed: Invalid authentication tag or corrupted data', 'AUTHENTICATION_FAILED');
    }
    
    throw new CryptoError('Decryption failed: ' + (error as Error).message, 'DECRYPTION_FAILED');
  }
}

export function encryptSecret(plaintext: string): string {
  if (!plaintext || typeof plaintext !== 'string') {
    throw new CryptoError('Plaintext must be a non-empty string', 'INVALID_PLAINTEXT');
  }

  try {
    const encrypted = encrypt(plaintext);
    
    const storedSecret: StoredSecret = {
      v: 1, // Version for future compatibility
      iv: encrypted.iv,
      tag: encrypted.tag,
      ct: encrypted.ciphertext
    };

    return JSON.stringify(storedSecret);
  } catch (error) {
    if (error instanceof CryptoError) {
      throw error;
    }
    throw new CryptoError('Failed to encrypt secret: ' + (error as Error).message, 'SECRET_ENCRYPTION_FAILED');
  }
}

export function decryptSecret(encryptedData: string): string {
  if (!encryptedData || typeof encryptedData !== 'string') {
    throw new CryptoError('Encrypted data must be a non-empty string', 'INVALID_ENCRYPTED_DATA');
  }

  try {
    const storedSecret: StoredSecret = JSON.parse(encryptedData);
    
    if (!storedSecret || typeof storedSecret !== 'object') {
      throw new CryptoError('Invalid encrypted data format', 'INVALID_DATA_FORMAT');
    }

    if (storedSecret.v !== 1) {
      throw new CryptoError('Unsupported encryption version', 'UNSUPPORTED_VERSION');
    }

    if (!storedSecret.iv || !storedSecret.tag || !storedSecret.ct) {
      throw new CryptoError('Incomplete encrypted data', 'INCOMPLETE_ENCRYPTED_DATA');
    }

    const payload: EncryptionPayload = {
      ciphertext: storedSecret.ct,
      iv: storedSecret.iv,
      tag: storedSecret.tag
    };

    return decrypt(payload);
  } catch (error) {
    if (error instanceof CryptoError) {
      throw error;
    }
    
    if (error instanceof SyntaxError) {
      throw new CryptoError('Invalid JSON format in encrypted data', 'INVALID_JSON');
    }
    
    throw new CryptoError('Failed to decrypt secret: ' + (error as Error).message, 'SECRET_DECRYPTION_FAILED');
  }
}

export function isEncrypted(data: string): boolean {
  try {
    const parsed = JSON.parse(data);
    return parsed && typeof parsed === 'object' && parsed.v === 1 && parsed.iv && parsed.tag && parsed.ct;
  } catch {
    return false;
  }
}

export function generateEncryptionKey(): string {
  return randomBytes(32).toString('hex');
}

export { CryptoError };