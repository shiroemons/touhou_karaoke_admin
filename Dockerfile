FROM ruby:3.1.2

WORKDIR /app

# Using Node.js v16.x(LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -

# Postgresql 14
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN apt install curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Add packages
RUN apt-get update && apt-get install -y \
      git \
      postgresql-client-14 \
      nodejs \
      vim

# Add yarnpkg for assets:precompile
RUN npm install -g yarn

# Add Chrome
RUN curl -sO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# Add chromedriver
RUN CHROME_DRIVER_VERSION=`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE` \
    && curl -sO https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip \
    && unzip chromedriver_linux64.zip \
    && mv chromedriver /usr/bin/chromedriver \
