FROM node:18-alpine as build
WORKDIR /app

RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app

COPY --from=build /app ./
EXPOSE 1337
CMD ["npm", "run", "start"]

