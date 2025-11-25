const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Job = require('../models/Job');

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
      .select('fullName email phone isProMember createdAt role serviceCategory panNumber problemsFixed moneySaved servicesUsed');

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
    const providerCount = await User.countDocuments({ role: 'provider' });
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

    // Compute real revenue from completed jobs
    const revenueAgg = await Job.aggregate([
      { $match: { status: 'completed' } },
      { $group: { _id: null, total: { $sum: '$totalPrice' } } },
    ]);

    const totalRevenue = revenueAgg[0]?.total || 0;

    // Compute weekly activity: number of jobs created in the last 7 days
    const now = new Date();
    const sevenDaysAgo = new Date(now);
    sevenDaysAgo.setDate(now.getDate() - 6); // include today + 6 previous days

    const recentJobsForWeek = await Job.find({
      createdAt: { $gte: new Date(sevenDaysAgo.setHours(0, 0, 0, 0)) },
    }).select('createdAt');

    const weeklyActivity = Array(7).fill(0);
    for (const job of recentJobsForWeek) {
      const createdAt = job.createdAt || job._id.getTimestamp?.() || null;
      if (!createdAt) continue;

      const dayDiff = Math.floor((now - createdAt) / (1000 * 60 * 60 * 24));
      const index = 6 - dayDiff; // index 6 = today, 0 = 6 days ago
      if (index >= 0 && index < 7) {
        weeklyActivity[index] += 1;
      }
    }

    // Recent analyses: use recent jobs as recent activity (user, service type, date, status)
    const recentJobs = await Job.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .populate('user', 'fullName email')
      .populate('service', 'name category');

    const recentAnalyses = recentJobs.map((job) => {
      const userName = job.user && job.user.fullName ? job.user.fullName : 'User';
      const serviceCategory = job.service && job.service.category
        ? job.service.category
        : job.service && job.service.name
          ? job.service.name
          : 'Service';
      const date = job.createdAt ? job.createdAt.toISOString().split('T')[0] : '';

      return {
        user: userName,
        type: serviceCategory,
        date,
        status: job.status,
      };
    });

    const dashboardData = {
      stats: {
        totalUsers,
        activeProviders: providerCount,
        revenue: totalRevenue, // in NPR, from completed jobs
        weeklyActivity,
      },
      recentUsers,
      recentAnalyses,
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
