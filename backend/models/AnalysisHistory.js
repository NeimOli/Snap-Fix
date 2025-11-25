const mongoose = require('mongoose');

const analysisHistorySchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  problem: {
    type: String,
    required: true,
    trim: true,
  },
  cause: {
    type: String,
    required: true,
  },
  solution: {
    type: [String],
    default: [],
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
});

module.exports = mongoose.model('AnalysisHistory', analysisHistorySchema);
