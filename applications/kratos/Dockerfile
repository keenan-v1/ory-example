FROM oryd/kratos:v0.11.1

COPY --chown=10000:ory src/ /

# These are used to generate the kratos.yaml file at runtime.
# Override these with environment variables
ENV ISSUER="Kratos"
ENV PUBLIC_BASE_URL="http://127.0.0.1:4433"
ENV ADMIN_BASE_URL="http://127.0.0.1:4434"
ENV DEFAULT_BROWSER_RETURN_URL="http://127.0.0.1:4455/"
ENV LOGIN_BASE_URL="http://127.0.0.1:4455"

# This controls database migrations
ENV MIGRATIONS_AUTO="true"

# These are configured via environment instead of the kratos.yaml file
ENV COURIER_SMTP_CONNECTION_URI="smtps://test:test@mailslurper:1025/?skip_ssl_verify=true"
ENV DSN="memory"
ENV SECRET_COOKIE="32-LONG-SECRET-NOT-SECURE-AT-ALL"
ENV SECRETS_CIPHER="32-LONG-SECRET-NOT-SECURE-AT-ALL"
ENV SECRETS_DEFAULT="32-LONG-SECRET-NOT-SECURE-AT-ALL"

# Escalate to root to install gettext and make the config directory
USER root

RUN apk --update upgrade && \
    apk --no-cache --update-cache --upgrade --latest add gettext

# Set back to kratos user
USER 10000

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4433/health/alive && curl -f http://localhost:4434/health/alive || exit 1

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
CMD ["kratos", "serve", "-c", "/home/ory/kratos.yaml"]