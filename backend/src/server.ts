import express, { Request, Response, NextFunction } from 'express';
import http from 'http';
import https from 'https';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { hospitalsRouter } from './routes/hospitals';
import { incidentsRouter } from './routes/incidents';
import { authRouter } from './routes/auth';
import { sentinelRouter } from './routes/sentinel';
import { abhaRouter } from './routes/abha';
import { auditRouter } from './routes/audit';
import { initSocketIO, getRecentTelemetry } from './socket';
import { getTlsCredentials } from './utils/tlsHelper';
import { startEscalationWatchdog } from './escalation';

dotenv.config();

// Process-level crash prevention guards for hackathon demo stability
process.on('unhandledRejection', (reason) => {
  console.warn('[Process Warning] Handled unhandledRejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('[Process Warning] Handled uncaughtException:', err);
});

export const app = express();
export const httpServer = http.createServer(app);

// TLS Dev/Prod Certificate Setup
const tlsCreds = getTlsCredentials();
export const httpsServer = tlsCreds ? https.createServer(tlsCreds, app) : null;

// Bind Socket.IO to HTTPS if USE_HTTPS is enabled, else HTTP
const useHttps = process.env.USE_HTTPS === 'true' && httpsServer !== null;
export const activeServer: http.Server | https.Server = (useHttps && httpsServer) ? httpsServer : httpServer;
export const io = initSocketIO(activeServer);

const PORT = parseInt(process.env.PORT || '5000', 10);

// Hardened Helmet configuration with strict Content Security Policy (CSP) & HSTS
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com'],
        imgSrc: ["'self'", 'data:', 'blob:', 'https:'],
        connectSrc: ["'self'", 'https:', 'wss:', 'http:', 'ws:'],
      },
    },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
  })
);

// Strict CORS Allowlist
const ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://localhost:3000',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:3000',
  'https://localhost:5173',
  process.env.CORS_ORIGIN,
].filter(Boolean) as string[];

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      const isAllowedExplicitly = ALLOWED_ORIGINS.includes(origin);
      const isLocalOrTunnel =
        origin.includes('localhost') ||
        origin.includes('127.0.0.1') ||
        origin.includes('192.168.') ||
        origin.includes('10.') ||
        origin.includes('172.') ||
        origin.includes('loca.lt') ||
        origin.includes('trycloudflare.com') ||
        origin.includes('ngrok');

      if (isAllowedExplicitly || isLocalOrTunnel || process.env.NODE_ENV !== 'production') {
        return callback(null, true);
      }
      return callback(new Error(`CORS blocked for unauthorized origin: ${origin}`));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Requested-With',
      'Accept',
      'x-device-id',
      'x-device-timestamp',
      'x-device-nonce',
      'x-device-signature',
      'x-bypass-hmac',
      'x-bypass-rate-limit',
    ],
  })
);

app.use(express.json({ limit: '10mb' }));

// Health check endpoint (Preserved from Phase 0)
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    service: 'rakshak-backend',
    tls: useHttps,
    timestamp: new Date().toISOString(),
    uptimeSeconds: process.uptime(),
  });
});

// Live Telemetry & Mobile Blackbox streaming feed endpoint
app.get('/telemetry/latest', (_req: Request, res: Response) => {
  res.status(200).json({
    count: getRecentTelemetry().length,
    telemetry: getRecentTelemetry(),
  });
});

// Root metadata endpoint
app.get('/', (_req: Request, res: Response) => {
  res.json({
    name: 'Rakshak-AI Geospatial Emergency Backend',
    version: '0.2.0',
    phase: 'Phase 26 - Security Hardened Production Layer',
    tls_enabled: useHttps,
    endpoints: {
      health: 'GET /health',
      hospitals: 'GET /hospitals (Optional: ?near=lat,long&radius_km=N)',
      create_incident: 'POST /incidents',
      get_incident: 'GET /incidents/:id',
      update_status: 'PATCH /incidents/:id/status',
      audit: 'GET /audit/verify-chain',
      refresh_token: 'POST /auth/refresh',
      delete_data: 'DELETE /auth/me/data',
    },
  });
});

// Mount Domain Routers
app.use('/auth', authRouter);
app.use('/api/auth', authRouter);
app.use('/hospitals', hospitalsRouter);
app.use('/incidents', incidentsRouter);
app.use('/sentinel', sentinelRouter);
app.use('/abha', abhaRouter);
app.use('/audit', auditRouter);
app.use('/api/audit', auditRouter);

// 404 Handler for undefined routes
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Endpoint not found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
});

// Global Error Handler
app.use(
  (
    err: Error,
    _req: Request,
    res: Response,
    _next: NextFunction,
  ) => {
    console.error('[Unhandled Global Error]', err.stack || err.message);
    res.status(500).json({
      error: 'Internal Server Error',
      message:
        process.env.NODE_ENV === 'production'
          ? 'An unexpected error occurred'
          : err.message,
    });
  },
);

// If this file is run directly (via ts-node or node), start the server
if (process.env.NODE_ENV !== 'test') {
  activeServer.listen(PORT, () => {
    const protocol = useHttps ? 'HTTPS / WSS' : 'HTTP / WS';
    console.log(
      `[Rakshak Backend] ${protocol} server running on port ${PORT}`,
    );
    // Start background auto-escalation heartbeat watchdog
    startEscalationWatchdog();
  });
}
