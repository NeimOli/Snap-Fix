const express = require('express');
const axios = require('axios');

const router = express.Router();

const DEFAULT_MODEL = process.env.HUGGING_FACE_MODEL || 'llava-hf/llava-1.5-7b-hf';

function normalizeBase64(imageBase64) {
  if (!imageBase64) return null;
  const commaIndex = imageBase64.indexOf('base64,');
  return commaIndex !== -1 ? imageBase64.substring(commaIndex + 7) : imageBase64;
}

function extractStepsFromText(text) {
  if (!text) return [];
  return text
    .split(/\n+/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => line.replace(/^\d+[\).\s-]*/g, '').trim());
}

router.post('/', async (req, res) => {
  try {
    const { imageBase64, description } = req.body || {};

    if (!imageBase64 || !description) {
      return res.status(400).json({
        success: false,
        message: 'Image and description are required'
      });
    }

    const modelId = process.env.HUGGING_FACE_MODEL || DEFAULT_MODEL;
    const normalizedModel = modelId.toLowerCase();
    const question = `${description}. Describe the issue and provide actionable, step-by-step repair guidance.`;
    const groqApiKey = process.env.GROQ_API_KEY;
    const groqModel = process.env.GROQ_MODEL;
    const useGroq = Boolean(groqApiKey && groqModel);

    const needsDataUri = normalizedModel.includes('qwen') && normalizedModel.includes('vl');
    const sanitizedImage = normalizeBase64(imageBase64);
    const finalImagePayload = needsDataUri ? imageBase64 : sanitizedImage;
    const imageDataUri = imageBase64?.startsWith('data:')
      ? imageBase64
      : `data:image/jpeg;base64,${sanitizedImage}`;

    if (useGroq) {
      try {
        const groqPrompt = question;

        const groqResponse = await axios.post(
          'https://api.groq.com/openai/v1/chat/completions',
          {
            model: groqModel,
            messages: [
              {
                role: 'user',
                content: groqPrompt
              }
            ],
            temperature: 0.2,
            max_tokens: 512
          },
          {
            headers: {
              Authorization: `Bearer ${groqApiKey}`,
              'Content-Type': 'application/json'
            },
            timeout: 60000
          }
        );

        const messageContent = groqResponse.data?.choices?.[0]?.message?.content;
        let combinedText = '';
        if (typeof messageContent === 'string') {
          combinedText = messageContent;
        } else if (Array.isArray(messageContent)) {
          combinedText = messageContent
            .map((item) => item.text || item.content || '')
            .filter(Boolean)
            .join('\n');
        }

        const steps = extractStepsFromText(combinedText);

        return res.json({
          success: true,
          provider: 'groq',
          summary: combinedText,
          steps
        });
      } catch (groqError) {
        const status = groqError.response?.status || 500;
        const groqMessage = groqError.response?.data?.error || groqError.message;
        console.error('[Analysis] Groq request failed', {
          status,
          groqMessage,
          url: groqError.config?.url,
        });

        return res.status(status).json({
          success: false,
          message: 'Failed to analyze the image via Groq. Please try again.',
          error: groqMessage,
        });
      }
    }

    const apiKey = process.env.HUGGING_FACE_API_KEY;
    if (!apiKey) {
      return res.status(500).json({
        success: false,
        message: 'Hugging Face API key is not configured on the server'
      });
    }

    const payload = needsDataUri
      ? {
          inputs: [
            {
              role: 'user',
              content: [
                { type: 'text', text: question },
                { type: 'image', image: finalImagePayload }
              ]
            }
          ],
          parameters: {
            max_new_tokens: 256,
            temperature: 0.2
          }
        }
      : {
          inputs: {
            question,
            image: finalImagePayload
          },
          parameters: {
            max_new_tokens: 256,
            temperature: 0.2
          }
        };

    const requestConfig = {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: 60000
    };

    let hfResponse;
    try {
      hfResponse = await axios.post(
        `https://router.huggingface.co/hf-inference/models/${modelId}`,
        payload,
        requestConfig
      );
    } catch (routerError) {
      if (routerError.response?.status !== 404) {
        throw routerError;
      }

      console.warn('[Analysis] Router returned 404, retrying via legacy endpoint', {
        modelId,
        routerMessage: routerError.response?.data?.error || routerError.message,
      });

      hfResponse = await axios.post(
        `https://api-inference.huggingface.co/models/${modelId}`,
        payload,
        {
          ...requestConfig,
          headers: {
            ...requestConfig.headers,
            'X-Wait-For-Model': 'true'
          }
        }
      );
    }

    const data = hfResponse.data;
    let combinedText = '';

    if (Array.isArray(data)) {
      combinedText = data
        .map((entry) => entry.generated_text || entry.answer || entry.output || '')
        .filter(Boolean)
        .join('\n');
    } else if (typeof data === 'object') {
      combinedText = data.generated_text || data.answer || JSON.stringify(data);
    } else if (typeof data === 'string') {
      combinedText = data;
    }

    const steps = extractStepsFromText(combinedText);

    return res.json({
      success: true,
      summary: combinedText,
      steps
    });
  } catch (error) {
    const status = error.response?.status || 500;
    const hfMessage = error.response?.data?.error || error.message;
    const message = status === 503
      ? 'Model is starting up. Please try again in a few seconds.'
      : 'Failed to analyze the image. Please try again.';

    console.error('[Analysis] Hugging Face request failed', {
      status,
      hfMessage,
      url: error.config?.url,
    });

    return res.status(status).json({
      success: false,
      message,
      error: hfMessage,
    });
  }
});

// Follow-up chat endpoint (text-only, no image required)
router.post('/chat', async (req, res) => {
  try {
    const { question, context } = req.body || {};

    if (!question) {
      return res.status(400).json({
        success: false,
        message: 'Question is required',
      });
    }

    const basePrompt =
      'You are a helpful home repair assistant. Answer the user\'s question clearly and concisely. If relevant, refer to the existing analysis context but do not repeat long text unless needed.';

    const fullPrompt = context
      ? `${basePrompt}\n\nPrevious analysis context:\n${context}\n\nUser question: ${question}`
      : `${basePrompt}\n\nUser question: ${question}`;

    const modelId = process.env.HUGGING_FACE_MODEL || DEFAULT_MODEL;
    const groqApiKey = process.env.GROQ_API_KEY;
    const groqModel = process.env.GROQ_MODEL;
    const useGroq = Boolean(groqApiKey && groqModel);

    if (useGroq) {
      try {
        const groqResponse = await axios.post(
          'https://api.groq.com/openai/v1/chat/completions',
          {
            model: groqModel,
            messages: [
              {
                role: 'user',
                content: fullPrompt,
              },
            ],
            temperature: 0.3,
            max_tokens: 512,
          },
          {
            headers: {
              Authorization: `Bearer ${groqApiKey}`,
              'Content-Type': 'application/json',
            },
            timeout: 60000,
          }
        );

        const messageContent = groqResponse.data?.choices?.[0]?.message?.content;
        let answer = '';
        if (typeof messageContent === 'string') {
          answer = messageContent;
        } else if (Array.isArray(messageContent)) {
          answer = messageContent
            .map((item) => item.text || item.content || '')
            .filter(Boolean)
            .join('\n');
        }

        return res.json({
          success: true,
          provider: 'groq',
          answer,
        });
      } catch (groqError) {
        const status = groqError.response?.status || 500;
        const groqMessage = groqError.response?.data?.error || groqError.message;
        console.error('[Analysis Chat] Groq request failed', {
          status,
          groqMessage,
          url: groqError.config?.url,
        });

        return res.status(status).json({
          success: false,
          message: 'Failed to process chat via Groq. Please try again.',
          error: groqMessage,
        });
      }
    }

    const apiKey = process.env.HUGGING_FACE_API_KEY;
    if (!apiKey) {
      return res.status(500).json({
        success: false,
        message: 'Hugging Face API key is not configured on the server',
      });
    }

    const payload = {
      inputs: fullPrompt,
      parameters: {
        max_new_tokens: 256,
        temperature: 0.3,
      },
    };

    const requestConfig = {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      timeout: 60000,
    };

    let hfResponse;
    try {
      hfResponse = await axios.post(
        `https://router.huggingface.co/hf-inference/models/${modelId}`,
        payload,
        requestConfig
      );
    } catch (routerError) {
      if (routerError.response?.status !== 404) {
        throw routerError;
      }

      console.warn('[Analysis Chat] Router returned 404, retrying via legacy endpoint', {
        modelId,
        routerMessage: routerError.response?.data?.error || routerError.message,
      });

      hfResponse = await axios.post(
        `https://api-inference.huggingface.co/models/${modelId}`,
        payload,
        {
          ...requestConfig,
          headers: {
            ...requestConfig.headers,
            'X-Wait-For-Model': 'true',
          },
        }
      );
    }

    const data = hfResponse.data;
    let answer = '';

    if (Array.isArray(data)) {
      answer = data
        .map((entry) => entry.generated_text || entry.answer || entry.output || '')
        .filter(Boolean)
        .join('\n');
    } else if (typeof data === 'object') {
      answer = data.generated_text || data.answer || JSON.stringify(data);
    } else if (typeof data === 'string') {
      answer = data;
    }

    return res.json({
      success: true,
      provider: 'huggingface',
      answer,
    });
  } catch (error) {
    const status = error.response?.status || 500;
    const hfMessage = error.response?.data?.error || error.message;

    console.error('[Analysis Chat] Hugging Face request failed', {
      status,
      hfMessage,
      url: error.config?.url,
    });

    return res.status(status).json({
      success: false,
      message: 'Failed to process chat message. Please try again.',
      error: hfMessage,
    });
  }
});

module.exports = router;
