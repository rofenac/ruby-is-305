FROM node:20-bookworm-slim AS frontend-build

WORKDIR /app/web-gui

COPY web-gui/package.json web-gui/package-lock.json ./
RUN npm ci

COPY web-gui/ ./
RUN npm run build

FROM ruby:3.3.6-slim

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential ca-certificates pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .
COPY --from=frontend-build /app/web-gui/dist /app/web-gui/dist

EXPOSE 4567

CMD ["sh", "-lc", "bundle exec puma -b tcp://0.0.0.0:${PORT:-4567} config.ru"]
