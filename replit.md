# ViraAI Project - Replit Configuration

## Project Overview
**ViraAI** is a cutting-edge global AI platform designed to empower creators, entrepreneurs, and businesses with advanced AI tools for content creation, branding, and monetization. This Phase 0 focuses on foundational architecture, security, and initial implementation strategies.

## Current State
- **Phase**: Phase 0 (Foundational setup)
- **Status**: Successfully imported and configured for Replit environment
- **Last Updated**: December 8, 2025

## Project Structure
- `index.js` - Main Express server entry point
- `package.json` - Node.js dependencies and scripts
- `jest.config.js` - Jest testing configuration
- `.gitignore` - Git ignore patterns for Node.js projects

## Technology Stack
- **Runtime**: Node.js (>=18.0.0)
- **Framework**: Express.js 4.18.2
- **Dev Tools**: ESLint, Jest, Nodemon
- **Package Manager**: npm (>=9.0.0)

## Replit Environment Configuration

### Server Configuration
- **Host**: 0.0.0.0 (required for Replit proxy)
- **Port**: 5000 (default, configurable via PORT env var)
- **Workflow**: "ViraAI Server" running `npm run dev` (with nodemon hot-reload)

### Available Scripts
- `npm start` - Start production server
- `npm run dev` - Development mode with hot-reload (nodemon)
- `npm run lint` - Run ESLint
- `npm run test` - Run Jest tests
- `npm run ci` - Run linting and tests

### Deployment
- **Type**: Autoscale (stateless web application)
- **Command**: `node index.js`
- **Configuration**: Configured via Replit deployment tools

## Recent Changes
- **2025-12-08**: Initial Replit environment setup
  - Configured Express server to bind to 0.0.0.0:5000
  - Created .gitignore for Node.js
  - Set up workflow for automatic server restart
  - Configured deployment settings for autoscale

## Development Notes
- The server must bind to `0.0.0.0` to work with Replit's proxy system
- Port 5000 is the only port exposed for web previews in Replit
- Nodemon is configured for hot-reload during development

## Future Development (Phase 0 Roadmap)
1. AI Video Production
2. AI Content Generation
3. AI Branding & Logo Design
4. AI Knowledge Products
5. Enterprise-level security protocols
6. CI/CD scaffolding and automated backup routines

## User Preferences
- No specific preferences documented yet
