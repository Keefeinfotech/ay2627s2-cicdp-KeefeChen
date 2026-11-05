import { FeedbackCategory, FeedbackStatus } from './feedback.model';

export interface CreateFeedbackDTO {
  category?: FeedbackCategory;
  title: string;
  description: string;
  rating?: number;
}

export interface UpdateFeedbackDTO {
  title?: string;
  description?: string;
  category?: FeedbackCategory;
  rating?: number;
}

export interface UpdateFeedbackStatusDTO {
  status: FeedbackStatus;
}

export interface RespondFeedbackDTO {
  response: string;
}

export interface FeedbackAnalytics {
  totalCount: number;
  statusBreakdown: Record<FeedbackStatus, number>;
  averageRating: number;
}