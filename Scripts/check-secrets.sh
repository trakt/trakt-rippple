#!/bin/sh

set -eu

SECRETS_FILE="${SRCROOT}/Rippple/Secrets.swift"

if [ ! -f "$SECRETS_FILE" ]; then
  echo "error: Missing Secrets.swift. Copy Secrets-Template.swift and fill in the required values." >&2
  exit 1
fi

FILTERED=$(grep -v '^[[:space:]]*//' "$SECRETS_FILE" || true)
if printf '%s\n' "$FILTERED" | grep -q '<#'; then
  echo "error: Secrets.swift contains template placeholders. Fill in all required values." >&2
  exit 1
fi

if printf '%s\n' "$FILTERED" | grep -vE '^[[:space:]]*static[[:space:]]+let[[:space:]]+secretId[[:space:]:=]' | grep -Eq '=[[:space:]]*""'; then
  echo "error: Secrets.swift contains empty string values. Only TraktAPIConfiguration.secretId may be empty." >&2
  exit 1
fi

# Read the literal configuration values, keeping secretId quoted so "" differs from a missing value.
TRAKT_SECRET=$(printf '%s\n' "$FILTERED" | sed -nE 's/^[[:space:]]*static[[:space:]]+let[[:space:]]+secretId([[:space:]]*:[[:space:]]*String)?[[:space:]]*=[[:space:]]*("[^"]*")[[:space:]]*(\/\/.*)?$/\2/p')
TRAKT_CALLBACK=$(printf '%s\n' "$FILTERED" | sed -nE 's/^[[:space:]]*static[[:space:]]+let[[:space:]]+callbackURL([[:space:]]*:[[:space:]]*String)?[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*(\/\/.*)?$/\2/p')

if [ -z "$TRAKT_SECRET" ] || [ -z "$TRAKT_CALLBACK" ]; then
  echo "error: Define secretId and callbackURL as string literals in Secrets.swift." >&2
  exit 1
fi

# Contributors: a client secret and ripl:// are allowed only in Debug builds.
if [ "$CONFIGURATION" = "Debug" ] && [ "$TRAKT_SECRET" != '""' ]; then
  case "$TRAKT_CALLBACK" in
    ripl://?*) exit 0 ;;
    *)
      echo "error: Debug login with a client secret requires a ripl:// callbackURL." >&2
      exit 1
      ;;
  esac
fi

# Team Debug builds and every Release/archive build must use PKCE and HTTPS.
if [ "$TRAKT_SECRET" != '""' ]; then
  echo 'error: Release builds require secretId = "" to use PKCE. Remove the Trakt client secret.' >&2
  exit 1
fi

case "$TRAKT_CALLBACK" in
  https://?*) ;;
  *)
    echo "error: PKCE login requires an https:// callbackURL on an associated domain." >&2
    exit 1
    ;;
esac
