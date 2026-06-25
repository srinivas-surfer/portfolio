const express = require('express');
const aws = require('aws-sdk');
const cors = require('cors');
require('dotenv').config();

const app = express();
const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(origin => origin.trim())
  .filter(Boolean);

app.use(express.json({ limit: '20kb' }));
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Not allowed by CORS'));
  }
}));

// Configure AWS SES
const ses = new aws.SES({
  region: process.env.AWS_REGION || 'ap-south-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

// Contact form endpoint
app.post('/api/contact', async (req, res) => {
  const name = String(req.body.name || '').trim();
  const email = String(req.body.email || '').trim();
  const company = String(req.body.company || '').trim();
  const message = String(req.body.message || '').trim();

  if (!name || !email || !message) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Invalid email address' });
  }

  const params = {
    Source: process.env.SES_FROM_EMAIL || 'noreply@example.com',
    Destination: {
      ToAddresses: [process.env.SES_TO_EMAIL || 'contact@example.com']
    },
    Message: {
      Subject: {
        Data: `New Opportunity Inquiry from ${name}`,
        Charset: 'UTF-8'
      },
      Body: {
        Html: {
          Data: `
            <h2>New Contact Form Submission</h2>
            <p><strong>Name:</strong> ${escapeHtml(name)}</p>
            <p><strong>Email:</strong> ${escapeHtml(email)}</p>
            <p><strong>Company:</strong> ${escapeHtml(company || 'Not provided')}</p>
            <p><strong>Message:</strong></p>
            <p>${escapeHtml(message).replace(/\n/g, '<br>')}</p>
          `,
          Charset: 'UTF-8'
        }
      }
    }
  };

  try {
    await ses.sendEmail(params).promise();
    console.log(`[${new Date().toISOString()}] Message sent from ${email}`);
    res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (error) {
    console.error('SES Error:', error);
    res.status(500).json({ error: 'Failed to send email' });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Escape HTML to prevent XSS
function escapeHtml(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return String(text).replace(/[&<>"']/g, m => map[m]);
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Contact service listening on port ${PORT}`);
});
