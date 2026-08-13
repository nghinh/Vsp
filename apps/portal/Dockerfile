# syntax=docker/dockerfile:1
# Build the Vue 3 / Vite portal, serve it with nginx which also reverse-proxies /api.
FROM node:22-alpine AS build
WORKDIR /build
COPY package.json package-lock.json ./
# @vitejs/plugin-vue@5.2 declares a vite ^5||^6 peer but the project pins vite 7
# (works fine at runtime); accept the stale peer range instead of failing the install.
RUN npm ci --legacy-peer-deps
COPY . .
# VITE_API_BASE_URL is intentionally left unset -> API_BASE defaults to "/api",
# which nginx reverse-proxies to the backend (same-origin, no CORS).
RUN npm run build

FROM nginx:alpine
COPY --from=build /build/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
