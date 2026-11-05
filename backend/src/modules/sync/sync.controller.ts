import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from './sync.types';
import { SyncService } from './sync.service';

export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  public getChanges = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user?.id || (req.query.userId as string);
      if (!userId) {
        res.status(400).json({ success: false, error: 'User ID is required.' });
        return;
      }

      const sinceParam = req.query.since as string | undefined;
      const since = sinceParam ? new Date(sinceParam) : new Date(0);

      const result = await this.syncService.getChangesSince(userId, since);
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  };

  public pushChanges = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const userId = req.user?.id || req.body.userId;
      if (!userId) {
        res.status(400).json({ success: false, error: 'User ID is required.' });
        return;
      }

      const changes = Array.isArray(req.body.changes) ? req.body.changes : [];
      const result = await this.syncService.pushChanges(userId, changes);

      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  };
}