const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');   // اضافه شد

const app = express();

app.use(helmet());
app.use(express.json());

// فعال‌سازی لاگ HTTP با Morgan
app.use(morgan('combined'));

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: "Too many requests from this IP, please try again later."
});
app.use("/api/", apiLimiter);

app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok", timestamp: new Date() });
});

app.get("/api/test", (req, res) => {
  res.json({ message: "API test route working fine." });
});

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';
app.listen(PORT, HOST, () => {
  console.log(`ViraAI server running on ${HOST}:${PORT}`);
});

module.exports = app;