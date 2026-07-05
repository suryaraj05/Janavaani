import express from 'express';
import cors from 'cors';
import submissionsRouter from './routes/submissions.js';
import clustersRouter from './routes/clusters.js';
import authRouter from './routes/auth.js';
import ingestRouter from './routes/ingest.js';
import identityRouter from './routes/identity.js';
import whatsappRouter from './routes/whatsapp.js';
import aiRouter from './routes/ai.js';
import hotspotsRouter from './routes/hotspots.js';
import developmentPlansRouter from './routes/developmentPlans.js';
import { getConstituencyCode, getConstituencyName } from './config.js';
import { JANAVAANI_DEPARTMENTS } from './services/analyze.js';

export function createApp(): express.Application {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '25mb' }));

  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      if (req.path.includes('/auth') || res.statusCode >= 400) {
        console.log(
          `${req.method} ${req.path} ${res.statusCode} ${Date.now() - start}ms`,
        );
      }
    });
    next();
  });

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'intake-api', version: '0.2.0' });
  });

  app.get('/', (_req, res) => {
    res.json({
      service: 'intake-api',
      message: "This is the People's Priorities REST API — not the web UI.",
      hint: 'Open the Flutter web app (not this URL). Example: flutter run -d chrome --web-port=5050 --dart-define=INTAKE_PORT=8092',
      app_url: 'http://localhost:5050',
      health: '/health',
      api: '/api/v1',
    });
  });

  app.get('/api/version', (_req, res) => {
    res.json({ success: true, version: '0.2.0', service: 'intake-api' });
  });

  app.get('/api/v1/config', (_req, res) => {
    res.json({
      success: true,
      data: {
        constituencyCode: getConstituencyCode(),
        constituencyName: getConstituencyName(),
        departments: [...JANAVAANI_DEPARTMENTS],
        categories: [...JANAVAANI_DEPARTMENTS],
        priorities: ['low', 'medium', 'high', 'urgent'],
        statuses: ['submitted', 'assigned', 'in_progress', 'resolved', 'closed', 'rejected'],
      },
    });
  });

  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/ai', aiRouter);
  app.use('/api/v1/submissions', submissionsRouter);
  app.use('/api/v1/clusters', clustersRouter);
  app.use('/api/v1/hotspots', hotspotsRouter);
  app.use('/api/v1/development-plans', developmentPlansRouter);
  app.use('/api/v1/ingest', ingestRouter);
  app.use('/api/v1/link', identityRouter);
  app.use('/api/v1/webhooks/whatsapp', whatsappRouter);

  return app;
}
