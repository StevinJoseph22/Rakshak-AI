/**
 * Safe timestamp parser to ensure dates returned from Postgres / backend / mobile
 * (which may lack explicit timezone offsets or have spaces instead of 'T')
 * are interpreted strictly as UTC before converting to local browser time (IST).
 */
export function parseTimestamp(raw?: string | Date | null): Date | null {
  if (!raw) return null;
  if (raw instanceof Date) return isNaN(raw.getTime()) ? null : raw;
  const str = String(raw).trim();
  if (!str) return null;

  // Format: "2026-10-17 10:58:00" or "2026-10-17T10:58:00" or with milliseconds, lacking timezone indicator
  if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:\.\d+)?$/.test(str)) {
    const d = new Date(str.replace(' ', 'T') + 'Z');
    return isNaN(d.getTime()) ? null : d;
  }

  const d = new Date(str);
  return isNaN(d.getTime()) ? null : d;
}

export function formatTimeSafe(raw?: string | Date | null, options?: Intl.DateTimeFormatOptions): string {
  const parsed = parseTimestamp(raw);
  if (!parsed) return 'Unknown';
  return parsed.toLocaleTimeString([], options);
}

export function formatDateTimeSafe(raw?: string | Date | null, options?: Intl.DateTimeFormatOptions): string {
  const parsed = parseTimestamp(raw);
  if (!parsed) return 'Never';
  return parsed.toLocaleString([], options);
}
