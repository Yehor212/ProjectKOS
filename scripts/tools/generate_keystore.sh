#!/bin/bash
set -euo pipefail

KEYSTORE_DIR="$(dirname "$0")/../../game/.keys"
KEYSTORE_PATH="$KEYSTORE_DIR/release.keystore"
ALIAS="kosgames"
PASSWORD="kosgamesrelease"
VALIDITY=10000
DNAME="CN=KOS GAMES, O=KOS GAMES, C=CA"

mkdir -p "$KEYSTORE_DIR"

if [ -f "$KEYSTORE_PATH" ]; then
    echo "Keystore already exists: $KEYSTORE_PATH"
    exit 0
fi

keytool -genkeypair \
    -keystore "$KEYSTORE_PATH" \
    -alias "$ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity "$VALIDITY" \
    -storepass "$PASSWORD" \
    -keypass "$PASSWORD" \
    -dname "$DNAME"

echo "Keystore generated: $KEYSTORE_PATH"
