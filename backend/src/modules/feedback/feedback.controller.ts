import { Request, Response, NextFunction } from 'express';
import { FeedbackService } from '../feedback/feedback.service';

const feedbackService = new FeedbackService();

const extractParamString = (param: unknown): string => {
  if (typeof param === 'string') return param;
  if (Array.isArray(param) && typeof param[0] === 'string') return param[0];
  return String(param || '');
};

export const createFeedback = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = (req as any).userId || (req as any).user?.id;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized request' });
      return;
    }
    const feedback = await feedbackService.submitFeedback(userId, req.body);
    res.status(201).json({ success: true, data: feedback });
  } catch (error: any) {
    next(error);
  }
};

export const getMyFeedback = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = (req as any).userId || (req as any).user?.id;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized request' });
      return;
    }
    const feedbacks = await feedbackService.getUserFeedbacks(userId);
    res.status(200).json({ success: true, data: feedbacks });
  } catch (error: any) {
    next(error);
  }
};

export const getFeedbackAnalytics = async (
  _req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const analytics = await feedbackService.getAnalytics();
    res.status(200).json({ success: true, data: analytics });
  } catch (error: any) {
    next(error);
  }
};

export const getAllFeedback = async (
  _req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const feedbacks = await feedbackService.getAllFeedback();
    res.status(200).json({ success: true, data: feedbacks });
  } catch (error: any) {
    next(error);
  }
};

export const updateFeedbackStatus = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const id = extractParamString(req.params.id);
    const updated = await feedbackService.updateStatus(id, req.body.status);
    res.status(200).json({ success: true, data: updated });
  } catch (error: any) {
    if (error.message?.includes('not found')) {
      res.status(404).json({ success: false, message: error.message });
      return;
    }
    next(error);
  }
};

export const respondToFeedback = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const id = extractParamString(req.params.id);
    const adminId = (req as any).userId || (req as any).user?.id;
    const updated = await feedbackService.addResponse(id, adminId, req.body.response);
    res.status(200).json({ success: true, data: updated });
  } catch (error: any) {
    if (error.message?.includes('not found')) {
      res.status(404).json({ success: false, message: error.message });
      return;
    }
    next(error);
  }
};

export const getFeedbackById = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const id = extractParamString(req.params.id);
    const userId = (req as any).userId || (req as any).user?.id;
    const role = (req as any).userRole || (req as any).user?.role;
    const isAdmin = role === 'ADMIN';

    const feedback = await feedbackService.getById(id, userId, isAdmin);
    res.status(200).json({ success: true, data: feedback });
  } catch (error: any) {
    if (error.message?.includes('Unauthorized')) {
      res.status(403).json({ success: false, message: error.message });
      return;
    }
    if (error.message?.includes('not found')) {
      res.status(404).json({ success: false, message: error.message });
      return;
    }
    next(error);
  }
};

export const updateFeedback = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const id = extractParamString(req.params.id);
    const userId = (req as any).userId || (req as any).user?.id;
    const role = (req as any).userRole || (req as any).user?.role;
    const isAdmin = role === 'ADMIN';

    const updated = await feedbackService.updateFeedback(id, userId, isAdmin, req.body);
    res.status(200).json({ success: true, data: updated });
  } catch (error: any) {
    if (error.message?.includes('Unauthorized')) {
      res.status(403).json({ success: false, message: error.message });
      return;
    }
    if (error.message?.includes('not found')) {
      res.status(404).json({ success: false, message: error.message });
      return;
    }
    next(error);
  }
};

export const deleteFeedback = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const id = extractParamString(req.params.id);
    const userId = (req as any).userId || (req as any).user?.id;
    const role = (req as any).userRole || (req as any).user?.role;
    const isAdmin = role === 'ADMIN';

    const success = await feedbackService.deleteFeedback(id, userId, isAdmin);
    if (!success) {
      res.status(404).json({ success: false, message: 'Feedback item not found or unauthorized' });
      return;
    }
    res.status(200).json({ success: true, message: 'Feedback deleted successfully' });
  } catch (error: any) {
    next(error);
  }
};