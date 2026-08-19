# syntax=docker/dockerfile:1

FROM ruby:3.3-slim AS builder

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set without "development test" && bundle install

FROM ruby:3.3-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .

RUN chmod +x docker-entrypoint.sh

EXPOSE 4567

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["bundle", "exec", "puma", "config.ru", "-p", "4567"]
