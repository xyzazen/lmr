FROM node:20-slim

RUN apt-get update && \
    apt-get install -y lua5.4 git ca-certificates python3 && \
    ln -sf /usr/bin/lua5.4 /usr/local/bin/lua && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

# Clone Lumarge, apply fix
RUN git clone --depth=1 https://github.com/tlredz/Lumarge lumarge && \
    bash fix_lumarge.sh lumarge

RUN mkdir -p temp

EXPOSE 3000
CMD ["node", "server.js"]
