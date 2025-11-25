const express = require('express');
const { protect } = require('../middleware/auth');
const Job = require('../models/Job');
const User = require('../models/User');
const Service = require('../models/Service');
const Message = require('../models/Message');

const router = express.Router();

// Utility: compute billable minutes with a 60-minute minimum and 30-minute blocks
function computeBillableMinutes(startTime, endTime) {
  const ms = endTime.getTime() - startTime.getTime();
  if (ms <= 0) return 60; // minimum 1 hour
  const minutes = Math.ceil(ms / 60000); // real minutes
  if (minutes <= 60) return 60;
  // round up to nearest 30 minutes for anything over 1 hour
  const over = minutes - 60;
  const blocks = Math.ceil(over / 30);
  return 60 + blocks * 30;
}

// @route   POST /api/jobs
// @desc    Create a new job when user requests a provider
// @access  Private (user)
router.post('/', protect, async (req, res) => {
  try {
    const { providerEmail, providerName, serviceId, description, preferredTime, ratePerHour } = req.body;

    if (!description || !providerEmail) {
      return res.status(400).json({
        success: false,
        message: 'Provider email and description are required',
      });
    }

    const userId = req.user.id;

    // Find provider user by email (optional but recommended)
    const providerUser = await User.findOne({ email: providerEmail, role: 'provider' });

    let service = null;
    if (serviceId) {
      service = await Service.findById(serviceId);
    }

    const hourlyRate =
      typeof ratePerHour === 'number'
        ? ratePerHour
        : service?.ratePerHour ?? 50; // default if nothing provided

    const job = await Job.create({
      user: userId,
      provider: providerUser ? providerUser._id : undefined,
      service: service ? service._id : undefined,
      description,
      preferredTime: preferredTime || '',
      status: 'requested',
      ratePerHour: hourlyRate,
      visitFee: 0,
    });

    res.status(201).json({ success: true, job });
  } catch (error) {
    console.error('[Jobs] Create job error:', error);
    res.status(500).json({ success: false, message: 'Server error while creating job' });
  }
});

// @route   POST /api/jobs/:id/rate
// @desc    User rates a completed job and updates provider service rating
// @access  Private (user)
router.post('/:id/rate', protect, async (req, res) => {
  try {
    let { rating } = req.body;

    rating = Number(rating);
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be a number between 1 and 5',
      });
    }

    const job = await Job.findById(req.params.id);
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    // Only the user who owns the job can rate it
    if (job.user.toString() !== req.user.id.toString()) {
      return res.status(403).json({ success: false, message: 'Not authorized to rate this job' });
    }

    if (job.status !== 'completed') {
      return res.status(400).json({ success: false, message: 'Only completed jobs can be rated' });
    }

    // Optional: prevent double rating
    if (job.rating && job.rating > 0) {
      return res.status(400).json({ success: false, message: 'Job has already been rated' });
    }

    job.rating = rating;
    await job.save();

    if (job.service) {
      const service = await Service.findById(job.service);
      if (service) {
        service.ratingsSum = (service.ratingsSum || 0) + rating;
        service.reviews = (service.reviews || 0) + 1;

        if (service.reviews > 0) {
          service.rating = service.ratingsSum / service.reviews;
        }

        await service.save();
      }
    }

    res.json({ success: true, job });
  } catch (error) {
    console.error('[Jobs] Rate job error:', error);
    res.status(500).json({ success: false, message: 'Server error while rating job' });
  }
});

// @route   POST /api/jobs/:id/accept
// @desc    Provider accepts a job
// @access  Private (provider)
router.post('/:id/accept', protect, async (req, res) => {
  try {
    const job = await Job.findById(req.params.id);
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    job.status = 'accepted';
    await job.save();

    // When a job is accepted, mark the related service as busy so other users see it as unavailable
    try {
      if (job.service) {
        await Service.findByIdAndUpdate(job.service, {
          availability: 'Busy with a job',
        });
      }
    } catch (serviceError) {
      console.error('[Jobs] Failed to update service availability on accept:', serviceError);
    }

    res.json({ success: true, job });
  } catch (error) {
    console.error('[Jobs] Accept job error:', error);
    res.status(500).json({ success: false, message: 'Server error while accepting job' });
  }
});

// @route   POST /api/jobs/:id/start
// @desc    Provider starts a job
// @access  Private (provider)
router.post('/:id/start', protect, async (req, res) => {
  try {
    const job = await Job.findById(req.params.id);
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    if (!job.startTime) {
      job.startTime = new Date();
    }
    job.status = 'in_progress';
    await job.save();

    // Mark related service as busy when a job is started
    try {
      if (job.service) {
        await Service.findByIdAndUpdate(job.service, {
          availability: 'Busy with a job',
        });
      }
    } catch (serviceError) {
      console.error('[Jobs] Failed to update service availability on start:', serviceError);
    }

    res.json({ success: true, job });
  } catch (error) {
    console.error('[Jobs] Start job error:', error);
    res.status(500).json({ success: false, message: 'Server error while starting job' });
  }
});

// @route   POST /api/jobs/:id/end
// @desc    Provider ends a job and calculates total price
// @access  Private (provider)
router.post('/:id/end', protect, async (req, res) => {
  try {
    const job = await Job.findById(req.params.id);
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    if (!job.startTime) {
      return res.status(400).json({ success: false, message: 'Job has not been started yet' });
    }

    const endTime = new Date();
    job.endTime = endTime;

    const billableMinutes = computeBillableMinutes(job.startTime, endTime);
    job.billableMinutes = billableMinutes;

    const hours = billableMinutes / 60;
    const total = job.visitFee + hours * job.ratePerHour;
    job.totalPrice = Math.round(total * 100) / 100; // round to 2 decimals
    job.status = 'completed';

    await job.save();

    // When a job is completed, mark the related service as available again.
    try {
      if (job.service) {
        await Service.findByIdAndUpdate(job.service, {
          availability: 'Available now',
        });
      }
    } catch (serviceError) {
      console.error('[Jobs] Failed to update service availability on end:', serviceError);
    }

    // Increment servicesUsed for the user so their profile reflects used professional services
    try {
      if (job.user) {
        const user = await User.findById(job.user);
        if (user) {
          user.servicesUsed = (user.servicesUsed || 0) + 1;
          await user.save();
        }
      }
    } catch (userError) {
      console.error('[Jobs] Failed to increment servicesUsed on job end:', userError);
    }

    res.json({ success: true, job });
  } catch (error) {
    console.error('[Jobs] End job error:', error);
    res.status(500).json({ success: false, message: 'Server error while ending job' });
  }
});

// @route   GET /api/jobs/user
// @desc    Get jobs for current user
// @access  Private
router.get('/user', protect, async (req, res) => {
  try {
    const jobs = await Job.find({ user: req.user.id })
      .populate('provider', 'fullName email phone')
      .populate('service', 'name category');

    res.json({ success: true, jobs });
  } catch (error) {
    console.error('[Jobs] Get user jobs error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching jobs' });
  }
});

// @route   GET /api/jobs/provider
// @desc    Get jobs for current provider
// @access  Private (provider)
router.get('/provider', protect, async (req, res) => {
  try {
    const jobs = await Job.find({ provider: req.user.id })
      .populate('user', 'fullName email phone')
      .populate('service', 'name category');

    res.json({ success: true, jobs });
  } catch (error) {
    console.error('[Jobs] Get provider jobs error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching provider jobs' });
  }
});

// @route   GET /api/jobs/:id/messages
// @desc    Get chat messages for a specific job (user or provider only)
// @access  Private
router.get('/:id/messages', protect, async (req, res) => {
  try {
    const job = await Job.findById(req.params.id).select('user provider');
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    const userId = req.user.id.toString();
    if (job.user.toString() !== userId && job.provider.toString() !== userId) {
      return res.status(403).json({ success: false, message: 'Not authorized to view this chat' });
    }

    const messages = await Message.find({ job: job._id })
      .sort({ createdAt: 1 });

    res.json({ success: true, messages });
  } catch (error) {
    console.error('[Jobs] Get job messages error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching messages' });
  }
});

// @route   POST /api/jobs/:id/messages
// @desc    Send a new chat message for a job (user or provider only)
// @access  Private
router.post('/:id/messages', protect, async (req, res) => {
  try {
    const { text } = req.body;
    if (!text || !text.trim()) {
      return res.status(400).json({ success: false, message: 'Message text is required' });
    }

    const job = await Job.findById(req.params.id).select('user provider');
    if (!job) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    const userId = req.user.id.toString();
    let fromRole;
    let to;

    if (job.user.toString() === userId) {
      fromRole = 'user';
      to = job.provider;
    } else if (job.provider.toString() === userId) {
      fromRole = 'provider';
      to = job.user;
    } else {
      return res.status(403).json({ success: false, message: 'Not authorized to send messages for this job' });
    }

    const message = await Message.create({
      job: job._id,
      from: req.user.id,
      to,
      text: text.trim(),
      fromRole,
    });

    res.status(201).json({ success: true, message });
  } catch (error) {
    console.error('[Jobs] Create job message error:', error);
    res.status(500).json({ success: false, message: 'Server error while sending message' });
  }
});

module.exports = router;
