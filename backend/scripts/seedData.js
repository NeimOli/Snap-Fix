const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Service = require('../models/Service');

dotenv.config();

// Seed sample repair services
const seedServices = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/snapfix');
    console.log('MongoDB Connected');

    // Clear existing services
    await Service.deleteMany({});

    // Sample services data
    const services = [
      {
        name: "Mike's Plumbing",
        category: "Plumbing",
        rating: 4.9,
        reviews: 127,
        distance: 0.8,
        price: "$75/hour",
        availability: "Available now",
        services: ["Faucet repair", "Pipe leaks", "Drain cleaning"],
        location: { latitude: 37.7749, longitude: -122.4194 }
      },
      {
        name: "Quick Fix Services",
        category: "Electronics",
        rating: 4.7,
        reviews: 89,
        distance: 1.2,
        price: "$65/hour",
        availability: "Available in 2 hours",
        services: ["Phone repair", "Laptop fixes", "TV repair"],
        location: { latitude: 37.7849, longitude: -122.4094 }
      },
      {
        name: "Pro Repair Co.",
        category: "Appliances",
        rating: 4.8,
        reviews: 203,
        distance: 2.1,
        price: "$85/hour",
        availability: "Available tomorrow",
        services: ["Washing machine", "Refrigerator", "Dishwasher"],
        location: { latitude: 37.7649, longitude: -122.4294 }
      },
      {
        name: "Furniture Fixers",
        category: "Furniture",
        rating: 4.6,
        reviews: 45,
        distance: 1.5,
        price: "$60/hour",
        availability: "Available now",
        services: ["Chair repair", "Table fixes", "Cabinet repair"],
        location: { latitude: 37.7749, longitude: -122.4094 }
      },
      {
        name: "Tech Solutions",
        category: "Electronics",
        rating: 4.9,
        reviews: 156,
        distance: 0.5,
        price: "$70/hour",
        availability: "Available in 1 hour",
        services: ["Computer repair", "Gaming console", "Audio equipment"],
        location: { latitude: 37.7749, longitude: -122.4194 }
      }
    ];

    await Service.insertMany(services);
    console.log('Services seeded successfully');
    process.exit(0);
  } catch (error) {
    console.error('Seed Error:', error);
    process.exit(1);
  }
};

seedServices();

