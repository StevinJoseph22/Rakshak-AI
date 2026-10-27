/**
 * Privacy & Log Redaction Utility (DPDP Act Compliance)
 * Masks sensitive PII (phone numbers, full names) before writing to persistent logs or console output.
 */

/**
 * Masks a telephone number, revealing only country prefix and last 3 digits.
 * Example: "+91 98450 12345" -> "+91 ******345"
 */
export function maskPhoneNumber(phone?: string | null): string {
  if (!phone) return '[REDACTED]';
  const trimmed = phone.trim();
  if (trimmed.length <= 4) return '***';
  const prefix = trimmed.startsWith('+91') ? '+91 ' : trimmed.slice(0, 3);
  const suffix = trimmed.slice(-3);
  return `${prefix}******${suffix}`;
}

/**
 * Masks a personal name to preserve privacy in application server logs.
 * Example: "Ramesh Kumar" -> "R***** K****"
 */
export function maskName(name?: string | null): string {
  if (!name) return '[REDACTED]';
  return name
    .split(' ')
    .map((part) => (part.length > 1 ? `${part[0]}${'*'.repeat(Math.max(part.length - 1, 2))}` : '*'))
    .join(' ');
}

/**
 * Redacts any string matching telephone or PII patterns in log messages.
 */
export function redactPii(message: string): string {
  // Regex to match Indian / International mobile numbers
  const phoneRegex = /(\+?\d{1,3}[-.\s]?)?(\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}/g;
  return message.replace(phoneRegex, (match) => maskPhoneNumber(match));
}
