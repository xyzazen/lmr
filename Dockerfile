FROM node:20-slim

# Install Lua 5.4 + git
RUN apt-get update && \
    apt-get install -y lua5.4 git ca-certificates && \
    ln -sf /usr/bin/lua5.4 /usr/local/bin/lua && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Node deps
COPY package*.json ./
RUN npm install --production

# Copy source
COPY . .

# Clone Lumarge if not already present
RUN if [ ! -f "lumarge/cli.lua" ] && [ ! -f "cli.lua" ]; then \
      git clone --depth=1 https://github.com/tlredz/Lumarge lumarge; \
    fi

# Create temp dir
RUN mkdir -p temp

EXPOSE 3000
CMD ["node", "server.js"]
