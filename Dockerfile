# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# Orbit for Cloudron. Orbit is one Rust binary with the web app embedded. The
# binary comes from the upstream release image, pinned by its multi-arch index
# digest, so the package runs exactly what upstream released (statically linked
# against musl, so it runs on the Ubuntu-based Cloudron image). nginx in the
# container sits between Cloudron's proxy and Orbit: see nginx.conf.template.
# No BuildKit-only syntax, so Cloudron's on-server build works.

ARG ORBIT_VERSION=0.2.1
ARG ORBIT_COMMIT=fe9dce7b155169cd02461d939dd0d6d8f9e50283

FROM ghcr.io/coollabsio/orbit:0.2.1@sha256:4ab1882b427a35cb9caa49f1694e14745b66c4d964b4223b6704a94b7a81ce61 AS orbit

FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee
ARG ORBIT_VERSION
ARG ORBIT_COMMIT
LABEL org.opencontainers.image.source="https://github.com/marcusquinn/cloudron-orbit-app"

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx openssl supervisor \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

ENV PATH=/app/code/bin:$PATH

WORKDIR /app/code
COPY --from=orbit /orbit /app/code/libexec/orbit
COPY start.sh nginx.conf.template supervisord.conf /app/code/
COPY lib/ /app/code/lib/
COPY bin/ /app/code/bin/
# The symlink lets a plain `supervisorctl stop orbit` work in the Web Terminal.
RUN chmod 0755 /app/code/start.sh /app/code/bin/* /app/code/libexec/orbit \
    && chmod 0644 /app/code/lib/* /app/code/nginx.conf.template /app/code/supervisord.conf \
    && ln -sf /app/code/supervisord.conf /etc/supervisor/supervisord.conf \
    && /app/code/libexec/orbit --help > /dev/null \
    && printf '%s\n' "${ORBIT_VERSION}" > /app/code/upstream-version \
    && printf '%s\n' "${ORBIT_COMMIT}" > /app/code/upstream-commit

EXPOSE 8000
CMD ["/app/code/start.sh"]
