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

# 1. Clone Prometheus as complete base (has all modules including namegenerators)
# 2. Overlay Lumarge modified files on top
# Lumarge repo is incomplete (under development) - missing namegenerators & other modules
RUN git clone --depth=1 https://github.com/prometheus-lua/Prometheus lumarge && \
    git clone --depth=1 https://github.com/tlredz/Lumarge /tmp/lumarge-src && \
    cp -f  /tmp/lumarge-src/cli.lua        lumarge/cli.lua && \
    cp -f  /tmp/lumarge-src/configs.json   lumarge/configs.json && \
    cp -rf /tmp/lumarge-src/source/*       lumarge/source/ && \
    rm -rf /tmp/lumarge-src

RUN mkdir -p temp

EXPOSE 3000
CMD ["node", "server.js"]
