const express = require('express');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const router = express.Router();

// @route   GET /api/users/profile
// @desc    Get user profile
// @access  Private
router.get('/profile', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    console.log(`[Users] Profile fetch success for ${user?.email || req.user.id}`);
    res.json({
      success: true,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        problemsFixed: user.problemsFixed,
        moneySaved: user.moneySaved,
        servicesUsed: user.servicesUsed,
        isProMember: user.isProMember,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt
      }
    });
  } catch (error) {
    console.error(`[Users] Profile fetch error for ${req.user?.id}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   POST /api/users/mark-fixed
// @desc    Mark a DIY fix as completed with a rating and update user stats
// @access  Private
router.post('/mark-fixed', protect, async (req, res) => {
  try {
    let { rating } = req.body;

    rating = Number(rating);
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be a number between 1 and 5',
      });
    }

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    user.problemsFixed = (user.problemsFixed || 0) + 1;
    user.totalRatingsCount = (user.totalRatingsCount || 0) + 1;
    user.totalRatingsSum = (user.totalRatingsSum || 0) + rating;

    await user.save();

    console.log(`[Users] Mark fixed success for ${user.email} (rating: ${rating})`);

    res.json({
      success: true,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        problemsFixed: user.problemsFixed,
        moneySaved: user.moneySaved,
        servicesUsed: user.servicesUsed,
        isProMember: user.isProMember,
        avatarUrl: user.avatarUrl,
        totalRatingsCount: user.totalRatingsCount,
        totalRatingsSum: user.totalRatingsSum,
      },
    });
  } catch (error) {
    console.error(`[Users] Mark fixed error for ${req.user?.id}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error',
    });
  }
});

// @route   PUT /api/users/avatar
// @desc    Update user avatar image (base64 data URL)
// @access  Private
router.put('/avatar', protect, async (req, res) => {
  try {
    const { avatarBase64 } = req.body;

    if (!avatarBase64 || typeof avatarBase64 !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'avatarBase64 is required'
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { avatarUrl: avatarBase64 },
      { new: true, runValidators: true }
    );

    console.log(`[Users] Avatar update success for ${user?.email || req.user.id}`);
    res.json({
      success: true,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        problemsFixed: user.problemsFixed,
        moneySaved: user.moneySaved,
        servicesUsed: user.servicesUsed,
        isProMember: user.isProMember,
        avatarUrl: user.avatarUrl
      }
    });
  } catch (error) {
    console.error(`[Users] Avatar update error for ${req.user?.id}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   PUT /api/users/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', protect, async (req, res) => {
  try {
    const { fullName, phone } = req.body;

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { fullName, phone },
      { new: true, runValidators: true }
    );

    console.log(`[Users] Profile update success for ${user?.email || req.user.id}`);
    res.json({
      success: true,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        problemsFixed: user.problemsFixed,
        moneySaved: user.moneySaved,
        servicesUsed: user.servicesUsed,
        isProMember: user.isProMember,
        avatarUrl: user.avatarUrl
      }
    });
  } catch (error) {
    console.error(`[Users] Profile update error for ${req.user?.id}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;

