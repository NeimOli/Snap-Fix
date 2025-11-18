const mongoose = require('mongoose');

const serviceSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  category: {
    type: String,
    enum: ['Plumbing', 'Electronics', 'Appliances', 'Furniture', 'All'],
    required: true
  },
  rating: {
    type: Number,
    default: 0,
    min: 0,
    max: 5
  },
  reviews: {
    type: Number,
    default: 0
  },
  distance: {
    type: Number, // in miles
    required: true
  },
  price: {
    type: String,
    required: true
  },
  availability: {
    type: String,
    required: true
  },
  services: [{
    type: String
  }],
  location: {
    latitude: Number,
    longitude: Number
  },
  phone: String,
  email: String,
  imageUrl: String
});

module.exports = mongoose.model('Service', serviceSchema);

