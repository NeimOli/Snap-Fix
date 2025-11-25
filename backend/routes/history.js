const express = require('express');
const AnalysisHistory = require('../models/AnalysisHistory');
const { protect } = require('../middleware/auth');

const router = express.Router();

// @route   GET /api/history
// @desc    Get analysis history for current user
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const items = await AnalysisHistory.find({ user: req.user.id })
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({
      success: true,
      items: items.map((item) => ({
        id: item._id,
        problem: item.problem,
        cause: item.cause,
        solution: item.solution,
        createdAt: item.createdAt,
      })),
    });
  } catch (error) {
    console.error(`[History] Fetch error for ${req.user?.id}:`, error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// @route   POST /api/history
// @desc    Save a new analysis history item
// @access  Private
router.post('/', protect, async (req, res) => {
  try {
    const { problem, cause, solution } = req.body;

    if (!problem || !cause) {
      return res.status(400).json({
        success: false,
        message: 'problem and cause are required',
      });
    }

    const history = await AnalysisHistory.create({
      user: req.user.id,
      problem,
      cause,
      solution: Array.isArray(solution) ? solution : [],
    });

    res.status(201).json({
      success: true,
      item: {
        id: history._id,
        problem: history.problem,
        cause: history.cause,
        solution: history.solution,
        createdAt: history.createdAt,
      },
    });
  } catch (error) {
    console.error(`[History] Create error for ${req.user?.id}:`, error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
