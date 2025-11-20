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
        isProMember: user.isProMember
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

