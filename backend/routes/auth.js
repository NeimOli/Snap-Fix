const express = require('express');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const Service = require('../models/Service');
const router = express.Router();

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '7d'
  });
};

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post('/register', [
  body('fullName').trim().notEmpty().withMessage('Full name is required'),
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('phone').trim().notEmpty().withMessage('Phone number is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { fullName, email, phone, password } = req.body;

    // Check if user already exists
    const userExists = await User.findOne({ email });
    if (userExists) {
      console.warn(`[Auth] Register attempt failed - existing user ${email}`);
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email'
      });
    }

    // Create user
    const user = await User.create({
      fullName,
      email,
      phone,
      password
    });

    // Generate token
    const token = generateToken(user._id);

    console.log(`[Auth] Register success for ${email}`);
    res.status(201).json({
      success: true,
      token,
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
        role: user.role,
        serviceCategory: user.serviceCategory,
        panNumber: user.panNumber,
      }
    });
  } catch (error) {
    console.error(`[Auth] Register error for ${req.body?.email || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error during registration'
    });
  }
});

// @route   POST /api/auth/register-provider
// @desc    Register a new service provider
// @access  Public
router.post('/register-provider', [
  body('fullName').trim().notEmpty().withMessage('Business name is required'),
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('phone').trim().notEmpty().withMessage('Phone number is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('serviceCategory').optional().trim(),
  body('panNumber').optional().trim(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array(),
      });
    }

    const { fullName, email, phone, password, serviceCategory, panNumber } = req.body;

    const existing = await User.findOne({ email });
    if (existing) {
      console.warn(`[Auth] Provider register failed - existing user ${email}`);
      return res.status(400).json({
        success: false,
        message: 'Account already exists with this email',
      });
    }

    const user = await User.create({
      fullName,
      email,
      phone,
      password,
      role: 'provider',
      serviceCategory: serviceCategory || '',
      panNumber: panNumber || '',
    });

    // Also create a basic Service listing so this provider appears in /api/services
    try {
      await Service.create({
        name: fullName,
        category: serviceCategory || 'All',
        rating: 0,
        reviews: 0,
        distance: 1, // placeholder; real distance can be added later
        price: 'Rs 0/hour',
        ratePerHour: 0,
        availability: 'Available now',
        services: [serviceCategory || 'General'],
        phone,
        email,
        imageUrl: '',
      });
    } catch (serviceError) {
      console.error('[Auth] Failed to create Service for provider', email, serviceError);
    }

    const token = generateToken(user._id);

    console.log(`[Auth] Provider register success for ${email}`);
    res.status(201).json({
      success: true,
      token,
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
        role: user.role,
        serviceCategory: user.serviceCategory,
        panNumber: user.panNumber,
      },
    });
  } catch (error) {
    console.error(`[Auth] Provider register error for ${req.body?.email || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error during provider registration',
    });
  }
});

// @route   POST /api/auth/login
// @desc    Login user
// @access  Public
router.post('/login', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { email, password, rememberMe } = req.body;

    // Check if user exists
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      console.warn(`[Auth] Login failed - no user found for ${email}`);
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      console.warn(`[Auth] Login failed - wrong password for ${email}`);
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Generate token
    const token = generateToken(user._id);

    console.log(`[Auth] Login success for ${email}`);
    res.json({
      success: true,
      token,
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
        role: user.role,
        serviceCategory: user.serviceCategory,
        panNumber: user.panNumber,
      }
    });
  } catch (error) {
    console.error(`[Auth] Login error for ${req.body?.email || 'unknown'}:`, error);
    res.status(500).json({
      success: false,
      message: 'Server error during login'
    });
  }
});

// @route   GET /api/auth/me
// @desc    Get current user
// @access  Private
router.get('/me', require('../middleware/auth').protect, async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
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
        role: user.role,
        serviceCategory: user.serviceCategory,
        panNumber: user.panNumber,
      }
    });
  } catch (error) {
    console.error('Get User Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;

