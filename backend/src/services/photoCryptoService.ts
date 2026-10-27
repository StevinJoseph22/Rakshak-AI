import crypto from 'crypto';

const MASTER_PHOTO_SECRET =
  process.env.PHOTO_ENCRYPTION_SECRET || 'rakshak-ai-incident-photo-master-secret-32b-min';
const HKDF_INFO = 'rakshak-photo-aes-256-gcm-v1';

export interface EncryptedPhotoEnvelope {
  v: number;
  alg: 'AES-256-GCM';
  iv: string; // Base64
  tag: string; // Base64
  data: string; // Base64 ciphertext
}

/**
 * Derives a cryptographically isolated 256-bit symmetric key per incident using HKDF-SHA256.
 * Even if an attacker compromises a single incident key, other incidents remain protected.
 */
export function deriveIncidentPhotoKey(incidentId: string): Buffer {
  const salt = Buffer.from(incidentId, 'utf8');
  const ikm = Buffer.from(MASTER_PHOTO_SECRET, 'utf8');
  const info = Buffer.from(HKDF_INFO, 'utf8');
  // Node.js crypto.hkdfSync(digest, ikm, salt, info, keylen)
  return Buffer.from(crypto.hkdfSync('sha256', ikm, salt, info, 32));
}

/**
 * Encrypts an incident photo (Base64 data URL or raw string) using AES-256-GCM before Redis storage.
 * Generates a fresh random 96-bit (12-byte) IV for each photo.
 */
export function encryptIncidentPhoto(incidentId: string, plainDataUrl: string): string {
  const derivedKey = deriveIncidentPhotoKey(incidentId);
  const iv = crypto.randomBytes(12);

  const cipher = crypto.createCipheriv('aes-256-gcm', derivedKey, iv);
  const ciphertext = Buffer.concat([
    cipher.update(Buffer.from(plainDataUrl, 'utf8')),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();

  const envelope: EncryptedPhotoEnvelope = {
    v: 1,
    alg: 'AES-256-GCM',
    iv: iv.toString('base64'),
    tag: authTag.toString('base64'),
    data: ciphertext.toString('base64'),
  };

  return `enc:v1:${JSON.stringify(envelope)}`;
}

/**
 * Decrypts an encrypted incident photo envelope retrieved from Redis RAM.
 * Authenticates ciphertext with GCM auth tag. If tampered, throws an error.
 */
export function decryptIncidentPhoto(incidentId: string, storedPayload: string): string {
  if (!storedPayload) return '';

  // Gracefully handle legacy unencrypted data URLs (e.g. data:image/jpeg;base64,...)
  if (storedPayload.startsWith('data:image/') || !storedPayload.startsWith('enc:v1:')) {
    return storedPayload;
  }

  const jsonStr = storedPayload.slice('enc:v1:'.length);
  const envelope: EncryptedPhotoEnvelope = JSON.parse(jsonStr);

  const derivedKey = deriveIncidentPhotoKey(incidentId);
  const iv = Buffer.from(envelope.iv, 'base64');
  const authTag = Buffer.from(envelope.tag, 'base64');
  const ciphertext = Buffer.from(envelope.data, 'base64');

  const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, iv);
  decipher.setAuthTag(authTag);

  const decrypted = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final(),
  ]);

  return decrypted.toString('utf8');
}
