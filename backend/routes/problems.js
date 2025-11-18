const express = require('express');
const multer = require('multer');
const Problem = require('../models/Problem');
const { protect } = require('../middleware/auth');
const { analyzeProblem } = require('../services/aiService');
const router = express.Router();

// Configure multer for file uploads (in memory)
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

// @route   POST /api/problems/analyze
// @desc    Analyze problem from image
// @access  Private
router.post('/analyze', protect, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Please upload an image'
      });
    }

    // Convert image to base64
    const imageBase64 = req.file.buffer.toString('base64');

    // Call AI service to analyze the problem
    const aiResult = await analyzeProblem(imageBase64);

    if (!aiResult.success) {
      return res.status(500).json({
        success: false,
        message: 'Failed to analyze image',
        error: aiResult.error
      });
    }

    // Save problem to database
    const problem = await Problem.create({
      userId: req.user.id,
      imageUrl: `data:image/jpeg;base64,${imageBase64}`, // In production, upload to cloud storage
      problemTitle: aiResult.analysis.problemTitle,
      problemDescription: aiResult.analysis.problemDescription,
      category: aiResult.analysis.category,
      aiAnalysis: JSON.stringify(aiResult.analysis),
      diySteps: aiResult.analysis.diySteps
    });

    res.status(201).json({
      success: true,
      problem: {
        id: problem._id,
        problemTitle: problem.problemTitle,
        problemDescription: problem.problemDescription,
        category: problem.category,
        diySteps: problem.diySteps,
        status: problem.status,
        createdAt: problem.createdAt
      }
    });
  } catch (error) {
    console.error('Analyze Problem Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during analysis'
    });
  }
});

// @route   GET /api/problems
// @desc    Get user's problems
// @access  Private
router.get('/', protect, async (req, res) => {
  try {
    const problems = await Problem.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({
      success: true,
      count: problems.length,
      problems
    });
  } catch (error) {
    console.error('Get Problems Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/problems/:id
// @desc    Get single problem
// @access  Private
router.get('/:id', protect, async (req, res) => {
  try {
    const problem = await Problem.findOne({
      _id: req.params.id,
      userId: req.user.id
    });

    if (!problem) {
      return res.status(404).json({
        success: false,
        message: 'Problem not found'
      });
    }

    res.json({
      success: true,
      problem
    });
  } catch (error) {
    console.error('Get Problem Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   PUT /api/problems/:id/status
// @desc    Update problem status
// @access  Private
router.put('/:id/status', protect, async (req, res) => {
  try {
    const { status } = req.body;

    const problem = await Problem.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      {
        status,
        fixedAt: status === 'Fixed' ? new Date() : null
      },
      { new: true }
    );

    if (!problem) {
      return res.status(404).json({
        success: false,
        message: 'Problem not found'
      });
    }

    // Update user stats if problem is fixed
    if (status === 'Fixed') {
      const User = require('../models/User');
      await User.findByIdAndUpdate(req.user.id, {
        $inc: { problemsFixed: 1 }
      });
    }

    res.json({
      success: true,
      problem
    });
  } catch (error) {
    console.error('Update Problem Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;

