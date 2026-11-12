import { FeedbackModel, IFeedback, FeedbackStatus } from "./feedback.model";
import { CreateFeedbackDTO, FeedbackAnalytics } from "./feedback.types";
import { Types } from "mongoose";

export class FeedbackRepository {
  async create(userId: string, data: CreateFeedbackDTO): Promise<IFeedback> {
    const feedback = new FeedbackModel({
      ...data,
      userId,
    });
    return await feedback.save();
  }

  async findById(id: string): Promise<IFeedback | null> {
    return await FeedbackModel.findById(id)
      .populate("userId", "name email")
      .populate("adminResponse.respondedBy", "name email")
      .exec();
  }

  async findByUserId(userId: string): Promise<IFeedback[]> {
    return await FeedbackModel.find({ userId }).sort({ createdAt: -1 }).exec();
  }

  async findAll(): Promise<IFeedback[]> {
    return await FeedbackModel.find()
      .populate("userId", "name email")
      .sort({ createdAt: -1 })
      .exec();
  }

  async update(
    id: string,
    data: Partial<IFeedback>,
  ): Promise<IFeedback | null> {
    return await FeedbackModel.findByIdAndUpdate(
      id,
      { $set: data },
      { new: true, runValidators: true },
    ).exec();
  }

  async addAdminResponse(
    id: string,
    adminId: string,
    message: string,
  ): Promise<IFeedback | null> {
    return await FeedbackModel.findByIdAndUpdate(
      id,
      {
        $set: {
          adminResponse: {
            respondedBy: adminId,
            message,
            respondedAt: new Date(),
          },
          status: FeedbackStatus.IN_REVIEW,
        },
      },
      { new: true },
    ).exec();
  }

  async delete(id: string, userId?: string): Promise<boolean> {
    const filter: any = { _id: new Types.ObjectId(id) };
    if (userId) {
      filter.userId = userId;
    }
    const result = await FeedbackModel.deleteOne(filter).exec();
    return result.deletedCount > 0;
  }

  async getAnalytics(): Promise<FeedbackAnalytics> {
    const totalCount = await FeedbackModel.countDocuments();

    const statusAggregation = await FeedbackModel.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]);

    const statusBreakdown = Object.values(FeedbackStatus).reduce(
      (acc, status) => {
        acc[status] = 0;
        return acc;
      },
      {} as Record<FeedbackStatus, number>,
    );

    statusAggregation.forEach((item) => {
      if (item._id in statusBreakdown) {
        statusBreakdown[item._id as FeedbackStatus] = item.count;
      }
    });

    const ratingAvg = await FeedbackModel.aggregate([
      { $match: { rating: { $exists: true, $ne: null } } },
      { $group: { _id: null, avgRating: { $avg: "$rating" } } },
    ]);

    return {
      totalCount,
      statusBreakdown,
      averageRating:
        ratingAvg.length > 0 ? Math.round(ratingAvg[0].avgRating * 10) / 10 : 0,
    };
  }
}
