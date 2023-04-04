#!/bin/sh

# Generate the configuration
envsubst < /home/ory/template.kratos.yaml > /home/ory/kratos.yaml

# Perform database migrations only if MIGRATIONS_AUTO is set to true
if [ "$MIGRATIONS_AUTO" = "true" ]; then
  kratos -c /home/ory/kratos.yaml migrate sql -e --yes
fi

exec "$@"