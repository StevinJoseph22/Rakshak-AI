import express, { Request, Response, NextFunction } from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { hospitalsRouter } from './routes/hospitals';
import { incidentsRouter } from './routes/incidents';
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

app.use(helmet());
app.use(
  cors({
    origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
    credentials: true,
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
    },
  });
});

// Mount Domain Routers
app.use('/hospitals', hospitalsRouter);
app.use('/incidents', incidentsRouter);

// 404 Handler for undefined routes
app.use((req: Request, res: Response) => {
  res.status(404).json({
    error: 'Endpoint not found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
});

// Global Error Handler
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error('[Unhandled Server Error]', err);
  res.status(500).json({
    error: 'Internal server error',
    message:
      process.env.NODE_ENV === 'production'
        ? 'An unexpected error occurred.'
        : err.message,
  });
});

if (process.env.NODE_ENV !== 'test') {
  httpServer.listen(PORT, () => {
    console.log(`[Rakshak Backend] Server & Socket.io listening on http://localhost:${PORT}`);
  });
}
