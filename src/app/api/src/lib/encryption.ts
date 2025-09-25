import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const TAG_LENGTH = 16;
const KEY_LENGTH = 32;

// Get encryption key from environment or generate ephemeral fallback
function getEncryptionKey(): Buffer {
  const envKey = process.env.SSH_SECRET;
  
  if (envKey) {
    // Use provided key, ensuring it's 32 bytes for AES-256
    const key = Buffer.from(envKey, 'utf8');
    if (key.length >= KEY_LENGTH) {
      return key.subarray(0, KEY_LENGTH);
    } else {
      // Pad shorter keys
      const paddedKey = Buffer.alloc(KEY_LENGTH);
      key.copy(paddedKey);
      return paddedKey;
    }
  }
  
  // Generate ephemeral key (will be different each app restart)
  console.warn('SSH_SECRET not provided, using ephemeral encryption key. Encrypted data will not persist across restarts.');
  return crypto.randomBytes(KEY_LENGTH);
}

export function encryptCredential(plaintext: string): string {
  // Handle empty/null inputs
  if (!plaintext || plaintext.trim() === '') {
    throw new Error('Cannot encrypt empty or null credential');
  }

  try {
    const key = getEncryptionKey();
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipher(ALGORITHM, key);
    cipher.setAAD(Buffer.from('credential'));

    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    const tag = cipher.getAuthTag();
    
    // Combine IV + encrypted data + auth tag
    const combined = Buffer.concat([iv, encrypted, tag]);
    
    return combined.toString('base64');
  } catch (error) {
    console.error('Encryption error:', error);
    throw new Error('Failed to encrypt credential');
  }
}

export function decryptCredential(encrypted: string): string {
  // Handle empty/null inputs
  if (!encrypted || encrypted.trim() === '') {
    throw new Error('Cannot decrypt empty or null encrypted data');
  }

  try {
    const key = getEncryptionKey();
    const combined = Buffer.from(encrypted, 'base64');
    
    if (combined.length < IV_LENGTH + TAG_LENGTH) {
      throw new Error('Invalid encrypted data format');
    }
    
    // Extract components
    const iv = combined.subarray(0, IV_LENGTH);
    const encryptedData = combined.subarray(IV_LENGTH, combined.length - TAG_LENGTH);
    const tag = combined.subarray(combined.length - TAG_LENGTH);
    
    const decipher = crypto.createDecipher(ALGORITHM, key);
    decipher.setAAD(Buffer.from('credential'));
    decipher.setAuthTag(tag);
    
    let decrypted = decipher.update(encryptedData, undefined, 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  } catch (error) {
    console.error('Decryption error:', error);
    throw new Error('Failed to decrypt credential - data may be corrupted or key mismatch');
  }
}