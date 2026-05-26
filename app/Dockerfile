FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

# Remove dev dependencies
RUN npm run build
# Remove dev dependencies
CMD ["node", "dist/src/index.js"]

# CMD ["npm", "start"]