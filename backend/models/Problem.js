const mongoose = require('mongoose');

const problemSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  imageUrl: {
    type: String,
    required: true
  },
  problemTitle: {
    type: String,
    required: true
  },
  problemDescription: {
    type: String,
    required: true
  },
  category: {
    type: String,
    enum: ['Electronics', 'Plumbing', 'Appliances', 'Furniture', 'Other'],
    default: 'Other'
  },
  aiAnalysis: {
    type: String,
    required: true
  },
  diySteps: [{
    stepNumber: Number,
    title: String,
    description: String,
    icon: String
  }],
  status: {
    type: String,
    enum: ['Analyzed', 'In Progress', 'Fixed', 'Closed'],
    default: 'Analyzed'
  },
  fixedAt: {
    type: Date
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Problem', problemSchema);

