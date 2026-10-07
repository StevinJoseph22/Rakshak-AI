import { BACKEND_API_BASE } from './socket';

export interface AuthUser {
  id: string;
  username: string;
  role: 'hospital_staff' | 'police' | 'ambulance';
  hospital_id: string | null;
  hospital_name?: string | null;
}

const TOKEN_KEY = 'rakshak_auth_token';
const USER_KEY = 'rakshak_auth_user';

export const getStoredToken = (): string | null => {
  try {
    return sessionStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
};

export const getStoredUser = (): AuthUser | null => {
  try {
    const raw = sessionStorage.getItem(USER_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

export const setStoredSession = (token: string, user: AuthUser): void => {
  try {
    sessionStorage.setItem(TOKEN_KEY, token);
    sessionStorage.setItem(USER_KEY, JSON.stringify(user));
  } catch (err) {
    console.warn('[Auth] Failed to write session to sessionStorage:', err);
  }
};

export const clearStoredSession = (): void => {
  try {
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(USER_KEY);
  } catch (err) {
    console.warn('[Auth] Failed to clear session from sessionStorage:', err);
  }
};

export const login = async (
  username: string,
  password: string
): Promise<{ token: string; user: AuthUser }> => {
  const res = await fetch(`${BACKEND_API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.message || 'Authentication failed');
  }

  setStoredSession(data.token, data.user);
  return { token: data.token, user: data.user };
};

export const authFetch = async (
  url: string,
  options: RequestInit = {}
): Promise<Response> => {
  const token = getStoredToken();
  const headers = new Headers(options.headers || {});
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  return fetch(url, { ...options, headers });
};
