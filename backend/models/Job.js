const mongoose = require('mongoose');

const jobSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    service: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Service',
    },
    description: {
      type: String,
      required: true,
      trim: true,
    },
    preferredTime: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ['requested', 'accepted', 'in_progress', 'completed', 'cancelled'],
      default: 'requested',
    },
    ratePerHour: {
      type: Number,
      required: true,
      min: 0,
    },
    visitFee: {
      type: Number,
      default: 0,
      min: 0,
    },
    startTime: {
      type: Date,
    },
    endTime: {
      type: Date,
    },
    billableMinutes: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalPrice: {
      type: Number,
      default: 0,
      min: 0,
    },
    cancelReason: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Job', jobSchema);
