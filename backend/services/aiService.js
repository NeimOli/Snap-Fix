const OpenAI = require('openai');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

/**
 * Analyze image and identify the problem
 * @param {String} imageBase64 - Base64 encoded image
 * @returns {Object} - AI analysis with problem identification and solution steps
 */
exports.analyzeProblem = async (imageBase64) => {
  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4-vision-preview",
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `Analyze this image of a household problem or broken item. Identify:
1. What the problem is (title and description)
2. The category (Electronics, Plumbing, Appliances, Furniture, or Other)
3. Step-by-step DIY repair instructions (4 steps with titles and descriptions)
4. Estimated difficulty level

Respond in JSON format:
{
  "problemTitle": "Problem name",
  "problemDescription": "Detailed description",
  "category": "Category name",
  "diySteps": [
    {
      "stepNumber": 1,
      "title": "Step title",
      "description": "Step description",
      "icon": "icon-name"
    }
  ]
}`
            },
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`
              }
            }
          ]
        }
      ],
      max_tokens: 1000
    });

    const content = response.choices[0].message.content;
    
    // Parse JSON response
    let analysis;
    try {
      // Extract JSON from markdown code blocks if present
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      analysis = JSON.parse(jsonMatch ? jsonMatch[0] : content);
    } catch (parseError) {
      // Fallback if JSON parsing fails
      analysis = {
        problemTitle: "Problem Identified",
        problemDescription: content,
        category: "Other",
        diySteps: [
          {
            stepNumber: 1,
            title: "Analyze the issue",
            description: "Carefully examine the problem area",
            icon: "search"
          },
          {
            stepNumber: 2,
            title: "Gather tools",
            description: "Collect necessary tools and materials",
            icon: "build"
          },
          {
            stepNumber: 3,
            title: "Follow repair steps",
            description: "Systematically work through the repair",
            icon: "handyman"
          },
          {
            stepNumber: 4,
            title: "Test and verify",
            description: "Test the repair to ensure it's working",
            icon: "check_circle"
          }
        ]
      };
    }

    return {
      success: true,
      analysis
    };
  } catch (error) {
    console.error('AI Analysis Error:', error);
    return {
      success: false,
      error: error.message,
      analysis: {
        problemTitle: "Analysis Error",
        problemDescription: "Unable to analyze the image. Please try again.",
        category: "Other",
        diySteps: []
      }
    };
  }
};

// Alternative: Google Gemini API implementation (uncomment if using Gemini)
/*
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

exports.analyzeProblemGemini = async (imageBase64) => {
  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-pro-vision' });
    
    const result = await model.generateContent([
      'Analyze this image and identify the problem. Provide step-by-step DIY repair instructions.',
      {
        inlineData: {
          data: imageBase64,
          mimeType: 'image/jpeg'
        }
      }
    ]);

    const response = await result.response;
    const text = response.text();

    // Parse response and return structured data
    return {
      success: true,
      analysis: parseGeminiResponse(text)
    };
  } catch (error) {
    console.error('Gemini AI Error:', error);
    return {
      success: false,
      error: error.message
    };
  }
};
*/

