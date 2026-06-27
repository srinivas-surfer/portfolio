const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();

const contactLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many contact requests from this IP, please try again later.' }
});

const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map(origin => origin.trim())
  .filter(Boolean);
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const smtpPort = Number(process.env.SMTP_PORT || 587);
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'email-smtp.ap-south-1.amazonaws.com',
  port: smtpPort,
  secure: process.env.SMTP_SECURE === 'true',
  requireTLS: smtpPort !== 465,
  auth: process.env.SMTP_USER && process.env.SMTP_PASS
    ? {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    : undefined
});

app.use(express.json({ limit: '20kb' }));
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Not allowed by CORS'));
  }
}));

app.post('/api/contact', contactLimiter, async (req, res) => {

  const name = String(req.body.name || '').trim();
  const email = String(req.body.email || '').trim();
  const company = String(req.body.company || '').trim();
  const message = String(req.body.message || '').trim();

  if (!name || !email || !message) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!emailPattern.test(email)) {
    return res.status(400).json({ error: 'Invalid email address' });
  }

  const configError = validateMailConfig();
  if (configError) {
    console.error(`SMTP configuration error: ${configError}`);
    return res.status(500).json({ error: 'Email service is not configured' });
  }

  const html = `
    <h2>New Contact Form Submission</h2>
    <p><strong>Name:</strong> ${escapeHtml(name)}</p>
    <p><strong>Email:</strong> ${escapeHtml(email)}</p>
    <p><strong>Company:</strong> ${escapeHtml(company || 'Not provided')}</p>
    <p><strong>Message:</strong></p>
    <p>${escapeHtml(message).replace(/\n/g, '<br>')}</p>
  `;

  try {
    await transporter.sendMail({
      from: process.env.SES_FROM_EMAIL,
      to: getRecipients(),
      replyTo: email,
      subject: `New Opportunity Inquiry from ${sanitizeHeader(name)}`,
      html
    });

    console.log(`[${new Date().toISOString()}] Message sent from ${email}`);
    res.status(200).json({ success: true, message: 'Email sent successfully' });
  } catch (error) {
    console.error('SES SMTP Error:', error);
    res.status(500).json({ error: 'Failed to send email' });
  }
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

function validateMailConfig() {
  const required = ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS', 'SES_FROM_EMAIL', 'SES_TO_EMAIL'];
  const missing = required.filter(key => !process.env[key]);
  if (missing.length > 0) {
    return `Missing ${missing.join(', ')}`;
  }

  if (!emailPattern.test(process.env.SES_FROM_EMAIL)) {
    return 'SES_FROM_EMAIL must be a valid email address';
  }

  const recipients = getRecipients();
  if (recipients.length === 0) {
    return 'SES_TO_EMAIL must contain at least one valid email address';
  }

  return '';
}

function getRecipients() {
  return String(process.env.SES_TO_EMAIL || '')
    .split(',')
    .map(emailAddress => emailAddress.trim())
    .filter(emailAddress => emailPattern.test(emailAddress));
}

function sanitizeHeader(text) {
  return String(text).replace(/[\r\n]/g, ' ').trim();
}

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
const server = app.listen(PORT, () => {
  console.log(`Contact service listening on port ${PORT}`);
});

function gracefulShutdown(signal) {
  console.log(`${signal} received. Shutting down gracefully.`);
  server.close(() => {
    transporter.close();
    console.log('HTTP server and SMTP transporter closed.');
    process.exit(0);
  });

  setTimeout(() => {
    console.error('Forced shutdown after timeout.');
    process.exit(1);
  }, 10000).unref();
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

