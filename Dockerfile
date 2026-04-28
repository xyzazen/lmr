FROM node:20-slim

# Install Lua 5.4
RUN apt-get update && apt-get install -y lua5.4 git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install --production

# Copy source
COPY . .

# Clone Lumarge CLI
RUN git clone --depth=1 https://github.com/tlredz/Lumarge lumarge

# Buat temp dir
RUN mkdir -p temp

EXPOSE 3000
CMD ["node", "server.js"]