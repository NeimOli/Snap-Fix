const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

// Admin verification middleware
function verifyAdmin(req, res, next) {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    if (!decoded?.isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. Admin privileges required.'
      });
    }

    req.admin = decoded;
    next();
  } catch (error) {
    console.error('Admin verification error:', error);
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
      error: error.message,
    });
  }
}

// Admin login endpoint
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    // Check admin credentials from environment variables (fallback to defaults)
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@snapfix.com';
    const adminPassword = process.env.ADMIN_PASSWORD || 'snapfix123@';

    // Verify credentials
    if (email !== adminEmail || password !== adminPassword) {
      return res.status(401).json({
        success: false,
        message: 'Invalid admin credentials'
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        email: adminEmail,
        role: 'admin',
        isAdmin: true 
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    res.json({
      success: true,
      message: 'Admin login successful',
      data: {
        token,
        admin: {
          email: adminEmail,
          role: 'admin'
        }
      }
    });

  } catch (error) {
    console.error('Admin login error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message
    });
  }
});

// Admin user management routes
router.get('/users', verifyAdmin, async (req, res) => {
  try {
    const users = await User.find()
      .sort({ createdAt: -1 })
      .select('fullName email phone isProMember createdAt');

    res.json({
      success: true,
      users,
    });
  } catch (error) {
    console.error('Admin get users error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch users',
      error: error.message,
    });
  }
});

router.put('/users/:id', verifyAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { fullName, phone, isProMember } = req.body;

    const updates = {};
    if (typeof fullName === 'string') updates.fullName = fullName.trim();
    if (typeof phone === 'string') updates.phone = phone.trim();
    if (typeof isProMember === 'boolean') updates.isProMember = isProMember;

    const user = await User.findByIdAndUpdate(id, updates, {
      new: true,
      runValidators: true,
      select: 'fullName email phone isProMember createdAt',
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    res.json({
      success: true,
      user,
    });
  } catch (error) {
    console.error('Admin update user error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update user',
      error: error.message,
    });
  }
});

router.delete('/users/:id', verifyAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const user = await User.findByIdAndDelete(id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    res.json({
      success: true,
      message: 'User deleted successfully',
    });
  } catch (error) {
    console.error('Admin delete user error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete user',
      error: error.message,
    });
  }
});

// Get admin profile (protected route)
router.get('/profile', verifyAdmin, (req, res) => {
  res.json({
    success: true,
    data: {
      email: req.admin.email,
      role: req.admin.role,
      isAdmin: req.admin.isAdmin
    }
  });
});

// Admin dashboard data (protected route)
router.get('/dashboard', verifyAdmin, async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const recentUsersFromDb = await User.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .select('fullName email createdAt isProMember');

    const recentUsers = recentUsersFromDb.map((user) => ({
      name: user.fullName,
      email: user.email,
      date: user.createdAt?.toISOString().split('T')[0],
      status: user.isProMember ? 'Pro Member' : 'Basic Member'
    }));

    const dashboardData = {
      stats: {
        totalUsers,
        activeAnalyses: 45,
        revenue: 245000, // in NPR
        weeklyActivity: [1, 3, 2, 5, 4, 6, 7]
      },
      recentUsers,
      recentAnalyses: [
        { user: 'John Doe', type: 'Plumbing', date: '2024-01-15', status: 'Completed' },
        { user: 'Jane Smith', type: 'Electrical', date: '2024-01-14', status: 'In Progress' },
        { user: 'Mike Johnson', type: 'Appliance', date: '2024-01-13', status: 'Completed' }
      ]
    };

    res.json({
      success: true,
      data: dashboardData
    });

  } catch (error) {
    console.error('Dashboard data error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch dashboard data',
      error: error.message
    });
  }
});

// Admin logout (client-side token removal)
router.post('/logout', verifyAdmin, (req, res) => {
  res.json({
    success: true,
    message: 'Admin logout successful'
  });
});

module.exports = router;
module.exports.verifyAdmin = verifyAdmin;
