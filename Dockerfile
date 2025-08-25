# Multi-stage Dockerfile for Jenkins CI/CD pipeline
FROM node:18-alpine AS base

# Install system dependencies for Apollo Rover
RUN apk add --no-cache \
    curl \
    bash \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Install Apollo Rover CLI
RUN curl -sSL https://rover.apollo.dev/nix/latest | sh && \
    mv /root/.rover/bin/rover /usr/local/bin/rover && \
    rm -rf /root/.rover

# Verify installations
RUN node --version && \
    npm --version && \
    rover --version

# Copy package files for dependency installation
COPY package*.json ./

# Install npm dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Expose port (if needed for testing)
EXPOSE 4002

# Default command
CMD ["node", "index.js"]
