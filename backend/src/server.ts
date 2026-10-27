import express, { Request, Response, NextFunction } from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { hospitalsRouter } from './routes/hospitals';
import { incidentsRouter } from './routes/incidents';
import { authRouter } from './routes/auth';
import { sentinelRouter } from './routes/sentinel';
import { abhaRouter } from './routes/abha';
import { auditRouter } from './routes/audit';
import { initSocketIO } from './socket';

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
export const io = initSocketIO(httpServer);
const PORT = process.env.PORT || 5000;

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }),
);
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      const isLocalOrLan =
        origin.includes('localhost') ||
        origin.includes('127.0.0.1') ||
        origin.includes('192.168.') ||
        origin.includes('10.') ||
        origin.includes('172.') ||
        origin.includes('loca.lt') ||
        origin.includes('trycloudflare.com') ||
        origin.includes('ngrok') ||
        origin === process.env.CORS_ORIGIN;
      if (isLocalOrLan || process.env.NODE_ENV !== 'production') {
        return callback(null, true);
      }
      return callback(new Error('CORS blocked for origin: ' + origin));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  }),
);
app.use(express.json());

// Health check endpoint (Preserved from Phase 0)
app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    service: 'rakshak-backend',
    timestamp: new Date().toISOString(),
    uptimeSeconds: process.uptime(),
  });
});

// Root metadata endpoint
app.get('/', (_req: Request, res: Response) => {
  res.json({
    name: 'Rakshak-AI Geospatial Emergency Backend',
    version: '0.2.0',
    phase: 'Phase 1 - Geospatial & Triage Data Layer',
    endpoints: {
      health: 'GET /health',
      hospitals: 'GET /hospitals (Optional: ?near=lat,long&radius_km=N)',
      create_incident: 'POST /incidents',
      get_incident: 'GET /incidents/:id',
      update_status: 'PATCH /incidents/:id/status',
      audit: 'GET /audit/verify-chain',
    },
  });
});

// Mount Domain Routers
app.use('/auth', authRouter);
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
  httpServer.listen(PORT, () => {
    console.log(
      `[Rakshak Backend] HTTP & Socket.IO server running on port ${PORT}`,
    );
  });
}
