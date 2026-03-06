#!/usr/bin/env bash
# ssm.sh — Manage /image-search SSM parameters independently of Terraform.
#
# Usage:
#   ./scripts/ssm.sh list                          # list all params under prefix
#   ./scripts/ssm.sh get  <KEY>                    # print one decrypted value
#   ./scripts/ssm.sh set  <KEY> <VALUE>            # create/overwrite one param
#   ./scripts/ssm.sh sync [--env-file .env]        # push every key from .env file
#   ./scripts/ssm.sh delete <KEY>                  # delete one param
#
# Environment:
#   SSM_PREFIX        default: /image-search
#   AWS_DEFAULT_REGION / AWS_PROFILE  — standard AWS env vars

set -euo pipefail

PREFIX="${SSM_PREFIX:-/image-search}"
REGION="${AWS_DEFAULT_REGION:-ap-south-1}"
ENV_FILE=".env"

# Keys stored as SecureString; everything else is String
SECURE_KEYS=(
  UNSPLASH_APP_ID
  UNSPLASH_ACCESS_KEY
  UNSPLASH_SECRET_KEY
  PEXELS_API_KEY
  PIXABAY_API_KEY
  FREEPIK_API_KEY
  POSTGRES_URL
  TYPESENSE_API_KEY
)

is_secure() {
  local key="$1"
  for k in "${SECURE_KEYS[@]}"; do
    [[ "$k" == "$key" ]] && return 0
  done
  return 1
}

param_type() {
  is_secure "$1" && echo "SecureString" || echo "String"
}

cmd_list() {
  echo "Parameters under ${PREFIX}:"
  aws ssm get-parameters-by-path \
    --region "$REGION" \
    --path "$PREFIX" \
    --with-decryption \
    --query "Parameters[*].{Name:Name,Type:Type,Modified:LastModifiedDate}" \
    --output table
}

cmd_get() {
  local key="${1:?usage: ssm.sh get <KEY>}"
  aws ssm get-parameter \
    --region "$REGION" \
    --name "${PREFIX}/${key}" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text
}

cmd_set() {
  local key="${1:?usage: ssm.sh set <KEY> <VALUE>}"
  local value="${2:?usage: ssm.sh set <KEY> <VALUE>}"
  local type
  type=$(param_type "$key")
  aws ssm put-parameter \
    --region "$REGION" \
    --name "${PREFIX}/${key}" \
    --value "$value" \
    --type "$type" \
    --overwrite \
    --tags "Key=App,Value=image-search" 2>/dev/null || \
  aws ssm put-parameter \
    --region "$REGION" \
    --name "${PREFIX}/${key}" \
    --value "$value" \
    --type "$type" \
    --overwrite
  echo "  [OK] ${PREFIX}/${key}  (${type})"
}

cmd_sync() {
  # Parse optional --env-file argument
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env-file) ENV_FILE="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -f "$ENV_FILE" ]] || { echo "ERROR: env file not found: $ENV_FILE" >&2; exit 1; }

  echo "Syncing '${ENV_FILE}' → SSM prefix '${PREFIX}' (region: ${REGION})"
  echo ""

  local ok=0 fail=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blanks and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    [[ "$line" != *"="* ]] && continue

    local key="${line%%=*}"
    local value="${line#*=}"

    if cmd_set "$key" "$value"; then
      (( ok++ )) || true
    else
      echo "  [FAIL] ${PREFIX}/${key}" >&2
      (( fail++ )) || true
    fi
  done < "$ENV_FILE"

  echo ""
  echo "Done — ${ok} pushed, ${fail} failed."
  [[ $fail -eq 0 ]] || exit 1
}

cmd_delete() {
  local key="${1:?usage: ssm.sh delete <KEY>}"
  aws ssm delete-parameter \
    --region "$REGION" \
    --name "${PREFIX}/${key}"
  echo "  [DELETED] ${PREFIX}/${key}"
}

usage() {
  grep '^# ' "$0" | sed 's/^# //'
  exit 1
}

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  list)   cmd_list ;;
  get)    cmd_get   "$@" ;;
  set)    cmd_set   "$@" ;;
  sync)   cmd_sync  "$@" ;;
  delete) cmd_delete "$@" ;;
  *)      usage ;;
esac
