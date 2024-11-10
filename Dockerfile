FROM ruby:3.3.0-bookworm

WORKDIR /app

# Using Node.js v20.x(LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# PostgreSQL
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN apt install curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Add packages
RUN apt-get update && apt-get install -y \
      git \
      postgresql-client-16 \
      nodejs \
      vim

# Add yarnpkg for assets:precompile
RUN npm install -g yarn

# Add Chromium
RUN apt-get update && apt-get install -y chromium

# Add chromedriver
RUN CHROME_DRIVER_VERSION=$(curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE) \
    && curl -sO https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip \
    && unzip chromedriver_linux64.zip \
    && mv chromedriver /usr/bin/chromedriver \
    && chmod +x /usr/bin/chromedriver \
    && rm chromedriver_linux64.zip