import { io, Socket } from 'socket.io-client';
import { getStoredToken } from './auth';

const BACKEND_URL =
  import.meta.env.VITE_BACKEND_URL ||
  (typeof window !== 'undefined'
    ? `${window.location.protocol}//${window.location.hostname}:5000`
    : 'http://localhost:5000');

let socketInstance: Socket | null = null;

export const getSocket = (): Socket => {
  const token = getStoredToken();
  if (!socketInstance) {
    socketInstance = io(BACKEND_URL, {
      auth: { token },
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      timeout: 10000,
    });
  } else {
    socketInstance.auth = { token };
    if (!socketInstance.connected) {
      socketInstance.connect();
    }
  }
  return socketInstance;
};

/**
 * Updates socket auth credentials and reconnects to trigger backend auto-room assignment.
 */
export const updateSocketAuth = (token: string | null = getStoredToken()): void => {
  const socket = getSocket();
  socket.auth = { token };
  if (socket.connected) {
    socket.disconnect().connect();
  } else {
    socket.connect();
  }
};

export const BACKEND_API_BASE = BACKEND_URL;

