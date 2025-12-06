#!/usr/bin/env bash
# Wrapper script to compile and run ALGOL W (.alw) programs using the AWE compiler.
# Usage: bash alw.sh program.alw
# - Produces output directly
# - Accepts interactive input (read) just like running locally
# - Leaves no compiled binaries behind (clean run)
#
# The script delegates compilation and execution to a pre-built Docker image
# generated from the Dockerfile in this directory ("abuajamieh/alw").
#
# Author: Maksim AbuAjamieh
# Date: 06/12/2025

set -euo pipefail

IMAGE="abuajamieh/alw"
ALW_FILE="${1:-}"
[ -z "$ALW_FILE" ] && { echo "need .alw file"; exit 1; }
[ ! -f "$ALW_FILE" ] && { echo "file not found: $ALW_FILE"; exit 1; }

BASENAME=$(basename "$ALW_FILE" .alw)

# detect TTY
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_FLAGS="-it"
else
    DOCKER_FLAGS="-i"
fi

echo "► Compiling with awe..."
docker run --rm \
  -v "$(pwd)":/work \
  -w /work \
  "$IMAGE" \
  "$ALW_FILE"

echo "► Running program..."
docker run $DOCKER_FLAGS --rm \
  --entrypoint /bin/sh \
  -v "$(pwd)":/work \
  -w /work \
  "$IMAGE" \
  -c "
    cp $BASENAME /tmp/$BASENAME &&
    cd /tmp &&
    chmod +x $BASENAME &&
    ( ./$BASENAME ) ;
    rc=\$? ;
    rm -f $BASENAME ;
    exit \$rc
  "

# cleanup of host binary
echo "► Cleaning local binary..."
rm -f "$BASENAME" 2>/dev/null || true

echo "✓ Completed."
