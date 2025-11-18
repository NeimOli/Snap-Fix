# SnapFix Backend API

Backend server for SnapFix - Photo-based problem solver application.

## Features

- **User Authentication**: Register and login with JWT tokens
- **MongoDB Database**: Store users, problems, and services
- **AI Image Analysis**: Integrate OpenAI Vision API for problem identification
- **RESTful API**: Clean API endpoints for all app features
- **File Upload**: Handle image uploads for problem analysis

## Tech Stack

- Node.js & Express.js
- MongoDB with Mongoose
- OpenAI API (GPT-4 Vision) for image analysis
- JWT for authentication
- Multer for file uploads
- Bcryptjs for password hashing

## Setup Instructions

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Environment Configuration

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/snapfix
JWT_SECRET=your-super-secret-jwt-key
OPENAI_API_KEY=your-openai-api-key
```

### 3. MongoDB Setup

#### Option A: Local MongoDB

Install MongoDB locally and start the service:

```bash
# macOS
brew services start mongodb-community

# Windows
# Start MongoDB service from Services

# Linux
sudo systemctl start mongod
```

#### Option B: MongoDB Atlas (Cloud)

1. Create account at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Create a free cluster
3. Get connection string and add to `.env`

### 4. OpenAI API Key

1. Sign up at [OpenAI](https://platform.openai.com/)
2. Create API key
3. Add to `.env` file

### 5. Seed Sample Data (Optional)

```bash
node scripts/seedData.js
```

### 6. Start Server

#### Development (with nodemon):

```bash
npm run dev
```

#### Production:

```bash
npm start
```

Server will run on `http://localhost:5000`

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user (Protected)

### Problems

- `POST /api/problems/analyze` - Analyze problem from image (Protected)
- `GET /api/problems` - Get user's problems (Protected)
- `GET /api/problems/:id` - Get single problem (Protected)
- `PUT /api/problems/:id/status` - Update problem status (Protected)

### Services

- `GET /api/services` - Get all repair services
- `GET /api/services/:id` - Get single service

### Users

- `GET /api/users/profile` - Get user profile (Protected)
- `PUT /api/users/profile` - Update user profile (Protected)

## Example API Calls

### Register User

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "John Doe",
    "email": "john@example.com",
    "phone": "1234567890",
    "password": "password123"
  }'
```

### Login

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

### Analyze Problem (with image)

```bash
curl -X POST http://localhost:5000/api/problems/analyze \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "image=@/path/to/image.jpg"
```

## Project Structure

```
backend/
├── config/          # Database configuration
├── middleware/      # Authentication middleware
├── models/          # MongoDB models (User, Problem, Service)
├── routes/          # API routes
├── services/        # AI service integration
├── scripts/         # Database seeding scripts
├── server.js        # Main server file
├── package.json     # Dependencies
└── .env             # Environment variables
```

## Next Steps

1. Connect Flutter app to this API
2. Add image storage (Cloudinary or AWS S3)
3. Implement video guide recommendations
4. Add email notifications
5. Deploy to cloud (Heroku, AWS, etc.)

## Notes

- All protected routes require JWT token in Authorization header
- Image uploads are currently stored as base64 (consider cloud storage for production)
- OpenAI API key is required for image analysis feature

