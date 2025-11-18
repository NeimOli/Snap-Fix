const express = require('express');
const Service = require('../models/Service');
const router = express.Router();

// @route   GET /api/services
// @desc    Get all repair services
// @access  Public
router.get('/', async (req, res) => {
  try {
    const { category = 'All', sort = 'distance' } = req.query;

    let query = {};
    if (category !== 'All') {
      query.category = category;
    }

    let sortQuery = {};
    switch (sort) {
      case 'distance':
        sortQuery = { distance: 1 };
        break;
      case 'rating':
        sortQuery = { rating: -1 };
        break;
      case 'price':
        sortQuery = { price: 1 };
        break;
      default:
        sortQuery = { distance: 1 };
    }

    const services = await Service.find(query)
      .sort(sortQuery)
      .limit(50);

    res.json({
      success: true,
      count: services.length,
      services
    });
  } catch (error) {
    console.error('Get Services Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// @route   GET /api/services/:id
// @desc    Get single service
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    const service = await Service.findById(req.params.id);

    if (!service) {
      return res.status(404).json({
        success: false,
        message: 'Service not found'
      });
    }

    res.json({
      success: true,
      service
    });
  } catch (error) {
    console.error('Get Service Error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;

