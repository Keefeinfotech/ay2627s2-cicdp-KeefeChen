import { Request, Response, NextFunction } from 'express';
import { CalendarService } from './calendar.service';
import { ICalendarEvent } from './calendar.model';

/**
 * Standard enterprise API response wrapper.
 */
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  errors?: any;
}

/**
 * Extended Request interface ensuring authenticated user context.
 */
export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email?: string;
    roles?: string[];
  };
}

export class CalendarController {
  constructor(
    private readonly calendarService: CalendarService = new CalendarService()
  ) {}

  /**
   * Helper to safely extract a single string from query parameters.
   */
  private extractQueryString(param: unknown): string | undefined {
    if (typeof param === 'string') return param;
    if (Array.isArray(param) && typeof param[0] === 'string') return param[0];
    return undefined;
  }

  /**
   * Helper to safely extract route params.
   */
  private extractParamString(param: unknown): string {
    if (typeof param === 'string') return param;
    if (Array.isArray(param) && typeof param[0] === 'string') return param[0];
    return String(param || '');
  }

  createEvent = async (
    req: AuthenticatedRequest,
    res: Response<ApiResponse<ICalendarEvent>>,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized request' });
        return;
      }

      const event = await this.calendarService.createEvent(userId, req.body);
      res.status(201).json({ success: true, data: event });
    } catch (error: any) {
      if (error.name === 'ValidationError' || error.isOperational) {
        res.status(400).json({ success: false, message: error.message });
        return;
      }
      next(error);
    }
  };

  getEvents = async (
    req: AuthenticatedRequest,
    res: Response<ApiResponse<ICalendarEvent[]>>,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized request' });
        return;
      }

      const startDateStr = this.extractQueryString(req.query.startDate);
      const endDateStr = this.extractQueryString(req.query.endDate);
      const groupId = this.extractQueryString(req.query.groupId);

      if (!startDateStr || !endDateStr) {
        res.status(400).json({
          success: false,
          message: 'Both startDate and endDate query parameters are required.',
        });
        return;
      }

      const startDate = new Date(startDateStr);
      const endDate = new Date(endDateStr);

      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        res.status(400).json({
          success: false,
          message: 'Invalid date format provided for startDate or endDate.',
        });
        return;
      }

      const events = await this.calendarService.getEventsForPeriod(
        userId,
        startDate,
        endDate,
        groupId
      );

      res.status(200).json({ success: true, data: events });
    } catch (error: any) {
      next(error);
    }
  };

  updateEvent = async (
    req: AuthenticatedRequest,
    res: Response<ApiResponse<ICalendarEvent>>,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized request' });
        return;
      }

      const id = this.extractParamString(req.params.id);
      if (!id) {
        res.status(400).json({ success: false, message: 'Event ID is required' });
        return;
      }

      const updated = await this.calendarService.updateEvent(
        id,
        userId,
        req.body
      );
      
      res.status(200).json({ success: true, data: updated });
    } catch (error: any) {
      if (error.message?.includes('not found') || error.message?.includes('unauthorized')) {
        res.status(404).json({ success: false, message: error.message });
        return;
      }
      next(error);
    }
  };

  deleteEvent = async (
    req: AuthenticatedRequest,
    res: Response<ApiResponse<null>>,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized request' });
        return;
      }

      const id = this.extractParamString(req.params.id);
      if (!id) {
        res.status(400).json({ success: false, message: 'Event ID is required' });
        return;
      }

      const success = await this.calendarService.deleteEvent(id, userId);
      if (!success) {
        res.status(404).json({ success: false, message: 'Event not found or unauthorized' });
        return;
      }

      res.status(200).json({ success: true, message: 'Event deleted successfully' });
    } catch (error: any) {
      next(error);
    }
  };

  checkScheduleConflicts = async (
    req: AuthenticatedRequest,
    res: Response<ApiResponse<{ hasConflict: boolean; conflictingEvents: ICalendarEvent[] }>>,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized request' });
        return;
      }

      const startTimeStr = this.extractQueryString(req.query.startTime);
      const endTimeStr = this.extractQueryString(req.query.endTime);
      const excludeId = this.extractQueryString(req.query.excludeId);

      if (!startTimeStr || !endTimeStr) {
        res.status(400).json({
          success: false,
          message: 'Both startTime and endTime parameters are required.',
        });
        return;
      }

      const startTime = new Date(startTimeStr);
      const endTime = new Date(endTimeStr);

      if (isNaN(startTime.getTime()) || isNaN(endTime.getTime())) {
        res.status(400).json({
          success: false,
          message: 'Invalid date format provided for startTime or endTime.',
        });
        return;
      }

      const result = await this.calendarService.checkConflicts(
        userId,
        startTime,
        endTime,
        excludeId
      );

      res.status(200).json({ success: true, data: result });
    } catch (error: any) {
      next(error);
    }
  };
}
