#!/bin/sh

# Extracts API key from initialize script
API_KEY="$(
  curl -s "localhost:$1/initialize.js" | \
  awk 'match($0, /"apiKey": "[^ ]*", /){print substr($0, RSTART+11, RLENGTH-11-3);}' \
)"

curl -H X-API-KEY:"$API_KEY" "localhost:$1/api/system/health"
