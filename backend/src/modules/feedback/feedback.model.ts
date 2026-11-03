import { Schema, model, Document, Types } from 'mongoose';

export enum FeedbackCategory {
  BUG = 'BUG',
  FEATURE_REQUEST = 'FEATURE_REQUEST',
  GENERAL = 'GENERAL',
  UI_UX = 'UI_UX',
}

export enum FeedbackStatus {
  PENDING = 'PENDING',
  IN_REVIEW = 'IN_REVIEW',
  RESOLVED = 'RESOLVED',
  DISMISSED = 'DISMISSED',
}

export interface IFeedback extends Document {
  userId: Types.ObjectId;
  category: FeedbackCategory;
  title: string;
  description: string;
  rating?: number;
  status: FeedbackStatus;
  adminResponse?: {
    respondedBy: Types.ObjectId;
    message: string;
    respondedAt: Date;
  };
  createdAt: Date;
  updatedAt: Date;
}

const FeedbackSchema = new Schema<IFeedback>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    category: {
      type: String,
      enum: Object.values(FeedbackCategory),
      default: FeedbackCategory.GENERAL,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 150,
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    rating: {
      type: Number,
      min: 1,
      max: 5,
    },
    status: {
      type: String,
      enum: Object.values(FeedbackStatus),
      default: FeedbackStatus.PENDING,
      index: true,
    },
    adminResponse: {
      respondedBy: { type: Schema.Types.ObjectId, ref: 'User' },
      message: { type: String, trim: true },
      respondedAt: { type: Date },
    },
  },
  { timestamps: true }
);

FeedbackSchema.index({ userId: 1, createdAt: -1 });

export const FeedbackModel = model<IFeedback>('Feedback', FeedbackSchema);