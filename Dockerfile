FROM ruby:4.0.6-bookworm

ARG NODE_MAJOR=24
ARG COREPACK_VERSION=0.35.0
ARG YARN_VERSION=4.18.0
ARG BUNDLER_VERSION=4.0.18

ENV COREPACK_HOME=/usr/local/share/corepack

WORKDIR /app

# Install repository keys before adding the NodeSource and PostgreSQL repositories.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
    && install -d -m 0755 /etc/apt/keyrings /usr/share/postgresql-common/pgdg \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
    && curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
      https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      chromium \
      chromium-driver \
      git \
      nodejs \
      postgresql-client-18 \
      vim \
    && npm install --global "corepack@${COREPACK_VERSION}" \
    && corepack enable \
    && corepack install --global "yarn@${YARN_VERSION}" \
    && gem install bundler -v "${BUNDLER_VERSION}" --no-document \
    && rm -rf /var/lib/apt/lists/*
