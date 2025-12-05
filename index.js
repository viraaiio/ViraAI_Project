'use strict';

// ViraAI Project - Phase 0
// Author: Lead Architect & Security Mentor
// Purpose: Foundational setup for enterprise AI platform (viraai.io)

const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Basic route
app.get('/', (req, res) => {
  res.send('Welcome to ViraAI Phase 0!');
});

// Start server
app.listen(PORT, function() {
  console.log('ViraAI server running on port ' + PORT);
});

// Export app for unit testing
module.exports = app;
