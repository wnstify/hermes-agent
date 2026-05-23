#!/usr/bin/env bash
# ForceCommand target for the gateway's SSH key.
# Pipes the gateway's SSH session into `docker exec` against the long-lived
# sandbox container, with /workspace as the starting working directory.
#
# Env propagation: env vars listed in PASSTHROUGH_VARS that are present in
# this wrapper's env (delivered by sshd via AcceptEnv + Hermes SendEnv) get
# forwarded into the container via `docker exec -e`. To add more, list them
# in PASSTHROUGH_VARS AND in /etc/ssh/sshd_config.d/30-accept-env.conf.

UID_NUM=$(id -u)
export XDG_RUNTIME_DIR="/run/user/${UID_NUM}"
export DOCKER_HOST="unix:///run/user/${UID_NUM}/docker.sock"
export PATH="${HOME}/bin:${PATH}"

# Rootless docker installs its binary to ~/bin/docker by default
# (via `dockerd-rootless-setuptool.sh install`).
DOCKER="${HOME}/bin/docker"

PASSTHROUGH_VARS=(GITHUB_TOKEN)
DOCKER_ENV_ARGS=()
for var in "${PASSTHROUGH_VARS[@]}"; do
  if [ -n "${!var-}" ]; then
    DOCKER_ENV_ARGS+=(-e "$var")
  fi
done

case "${SSH_ORIGINAL_COMMAND:-}" in
  ""|"bash"|"bash -l"|"bash -i"|"-bash") : ;;
  *)
    exec "$DOCKER" exec -i "${DOCKER_ENV_ARGS[@]}" -w /workspace hermes-sandbox-shell bash -lc "$SSH_ORIGINAL_COMMAND"
    ;;
esac
exec "$DOCKER" exec -i "${DOCKER_ENV_ARGS[@]}" -w /workspace hermes-sandbox-shell bash -l
