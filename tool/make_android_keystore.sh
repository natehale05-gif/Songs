#!/usr/bin/env bash
# Create the Android release signing key and print the GitHub secrets to add.
#
#   tool/make_android_keystore.sh
#
# Android refuses to install an unsigned APK, and an app can only be updated
# in place by a build signed with the SAME key. Generate this once and keep
# it safe — losing it means future releases cannot upgrade an installed app,
# only replace it after an uninstall.
#
# The keystore and android/key.properties are both gitignored. Never commit them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="$ROOT/android/upload-keystore.jks"
ALIAS="upload"

if [ -f "$KEYSTORE" ]; then
  echo "error: $KEYSTORE already exists — refusing to overwrite a signing key." >&2
  echo "Delete it deliberately if you really want a new one." >&2
  exit 1
fi

if [ -n "${KEYSTORE_PASSWORD:-}" ]; then
  password="$KEYSTORE_PASSWORD"
else
  read -rsp "Choose a keystore password: " password; echo
  read -rsp "Confirm: " confirm; echo
  [ "$password" = "$confirm" ] || { echo "passwords did not match" >&2; exit 1; }
fi
[ ${#password} -ge 6 ] || { echo "password must be at least 6 characters" >&2; exit 1; }

keytool -genkeypair \
  -keystore "$KEYSTORE" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$password" -keypass "$password" \
  -dname "CN=Songs of the Church, OU=Unknown, O=Unknown, L=Unknown, S=Unknown, C=US"

cat > "$ROOT/android/key.properties" <<EOF
storePassword=$password
keyPassword=$password
keyAlias=$ALIAS
storeFile=upload-keystore.jks
EOF

echo
echo "Created:"
echo "  android/upload-keystore.jks   (gitignored — back this up somewhere safe)"
echo "  android/key.properties        (gitignored)"
echo
echo "Local release builds are now properly signed."
echo
echo "For CI, add these four repository secrets at"
echo "  Settings -> Secrets and variables -> Actions -> New repository secret"
echo
echo "  ANDROID_KEYSTORE_BASE64  (the single line below)"
echo "  ANDROID_KEYSTORE_PASSWORD = $password"
echo "  ANDROID_KEY_PASSWORD      = $password"
echo "  ANDROID_KEY_ALIAS         = $ALIAS"
echo
echo "----- ANDROID_KEYSTORE_BASE64 -----"
base64 -w0 "$KEYSTORE"; echo
echo "-----------------------------------"
