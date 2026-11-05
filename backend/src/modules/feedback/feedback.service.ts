import { FeedbackRepository } from './feedback.repository';
import { IFeedback, FeedbackStatus } from './feedback.model';
import { CreateFeedbackDTO, UpdateFeedbackDTO, FeedbackAnalytics } from './feedback.types';

export class FeedbackService {
  private repository: FeedbackRepository;

  constructor(repository: FeedbackRepository = new FeedbackRepository()) {
    this.repository = repository;
  }

  async submitFeedback(userId: string, data: CreateFeedbackDTO): Promise<IFeedback> {
    return await this.repository.create(userId, data);
  }

  async getUserFeedbacks(userId: string): Promise<IFeedback[]> {
    return await this.repository.findByUserId(userId);
  }

  async getAllFeedback(): Promise<IFeedback[]> {
    return await this.repository.findAll();
  }

  async getById(id: string, requesterId: string, isAdmin: boolean): Promise<IFeedback> {
    const feedback = await this.repository.findById(id);
    if (!feedback) {
      throw new Error('Feedback item not found');
    }
    if (!isAdmin && feedback.userId.toString() !== requesterId) {
      throw new Error('Unauthorized access to feedback');
    }
    return feedback;
  }

  async updateStatus(id: string, status: FeedbackStatus): Promise<IFeedback> {
    const updated = await this.repository.update(id, { status });
    if (!updated) {
      throw new Error('Feedback item not found');
    }
    return updated;
  }

  async addResponse(id: string, adminId: string, response: string): Promise<IFeedback> {
    const updated = await this.repository.addAdminResponse(id, adminId, response);
    if (!updated) {
      throw new Error('Feedback item not found');
    }
    return updated;
  }

  async updateFeedback(
    id: string,
    userId: string,
    isAdmin: boolean,
    data: UpdateFeedbackDTO
  ): Promise<IFeedback> {
    const existing = await this.repository.findById(id);
    if (!existing) {
      throw new Error('Feedback item not found');
    }
    if (!isAdmin && existing.userId.toString() !== userId) {
      throw new Error('Unauthorized update request');
    }
    const updated = await this.repository.update(id, data);
    if (!updated) {
      throw new Error('Failed to update feedback');
    }
    return updated;
  }

  async deleteFeedback(id: string, userId: string, isAdmin: boolean): Promise<boolean> {
    return await this.repository.delete(id, isAdmin ? undefined : userId);
  }

  async getAnalytics(): Promise<FeedbackAnalytics> {
    return await this.repository.getAnalytics();
  }
}