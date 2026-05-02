# syntax=docker/dockerfile:1.4
# check=error=true
FROM ghcr.io/astral-sh/uv:python3.13-alpine AS builder

WORKDIR /app

ENV UV_SYSTEM_PYTHON=1
ENV UV_PROJECT_ENVIRONMENT=/usr/local

ARG UV_PARAMS="--only-group default --only-group llms --only-group cli"

RUN apk add --no-cache \
    build-base \
    cmake \
    pkgconfig \
    linux-headers

# Install dependencies to system Python
RUN --mount=type=cache,target=/root/.cache/uv,id=uv-${PROJECT_MODE} \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev ${UV_PARAMS}

# Copy project files
ADD pyproject.toml uv.lock ./

# Install the project to system Python
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev ${UV_PARAMS}

FROM python:3.13-alpine AS main

ARG version
ENV VERSION=$version
ARG PROJECT_MODE
ENV PROJECT_MODE=$PROJECT_MODE

RUN addgroup user && \
    adduser -s /bin/bash -D -G user user

# Install runtime dependencies
RUN apk add --no-cache \
    libedit \
    krb5-libs \
    openldap \
    postgresql18-client

COPY --from=builder /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

ADD polarsen/ polarsen/
ADD sql/ sql/

USER user

ENTRYPOINT ["python", "-m", "polarsen"]

