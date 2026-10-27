import fs from 'fs';
import path from 'path';

export interface TlsCredentials {
  key: Buffer;
  cert: Buffer;
}

const CERTS_DIR = path.resolve(__dirname, '../../certs');
const CERT_FILE = path.join(CERTS_DIR, 'cert.pem');
const KEY_FILE = path.join(CERTS_DIR, 'key.pem');

/**
 * Returns TLS credentials if configured or dev certs exist on disk.
 */
export function getTlsCredentials(): TlsCredentials | null {
  try {
    const customCert = process.env.SSL_CERT_PATH;
    const customKey = process.env.SSL_KEY_PATH;

    if (customCert && customKey && fs.existsSync(customCert) && fs.existsSync(customKey)) {
      return {
        cert: fs.readFileSync(customCert),
        key: fs.readFileSync(customKey),
      };
    }

    if (fs.existsSync(CERT_FILE) && fs.existsSync(KEY_FILE)) {
      return {
        cert: fs.readFileSync(CERT_FILE),
        key: fs.readFileSync(KEY_FILE),
      };
    }

    return null;
  } catch (err) {
    console.warn('[TLS Warning] Failed to initialize TLS credentials:', err);
    return null;
  }
}
