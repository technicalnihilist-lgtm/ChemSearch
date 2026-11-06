#!/usr/bin/env bash
# Build a signed ChemSearch APK without Gradle — just aapt2 + javac + d8 + apksigner.
#
# Requirements: JDK 11+ (javac), Android SDK build-tools 34 and platform android-34.
#   export ANDROID_HOME=$HOME/Android/Sdk
#   export JAVA_HOME=/path/to/jdk
#   ./android/build.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AND="$(cd "$(dirname "$0")" && pwd)"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
BT="${BUILD_TOOLS:-$(ls -d "$SDK"/build-tools/*/ 2>/dev/null | sort -V | tail -1)}"
BT="${BT%/}"
PLAT="${ANDROID_JAR:-$SDK/platforms/android-34/android.jar}"

[ -x "$BT/aapt2" ] || { echo "aapt2 not found in $BT"; exit 1; }
[ -f "$PLAT" ]     || { echo "android.jar not found at $PLAT"; exit 1; }
command -v javac >/dev/null || { echo "javac not on PATH"; exit 1; }

VERSION_NAME="1.1.0"
VERSION_CODE="2"

cd "$AND"
rm -rf build
mkdir -p build/classes build/dex assets
cp "$ROOT/index.html" assets/index.html

echo "== aapt2 compile"
"$BT/aapt2" compile --dir res -o build/res.zip

echo "== aapt2 link"
"$BT/aapt2" link -o build/base.apk \
  -I "$PLAT" \
  --manifest AndroidManifest.xml \
  -A assets \
  --min-sdk-version 24 --target-sdk-version 34 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" \
  build/res.zip

echo "== javac"
javac -source 8 -target 8 -classpath "$PLAT" -d build/classes \
  $(find src -name '*.java')

echo "== d8"
"$BT/d8" --lib "$PLAT" --min-api 24 --output build/dex $(find build/classes -name '*.class')

echo "== package"
cp build/dex/classes.dex build/classes.dex
(cd build && zip -q -u base.apk classes.dex && "$BT/zipalign" -f -p 4 base.apk aligned.apk)

echo "== keystore"
KS="$AND/chemsearch.jks"
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -alias chemsearch \
    -keyalg RSA -keysize 2048 -validity 12000 \
    -storepass chemsearch -keypass chemsearch \
    -dname "CN=ChemSearch, OU=Apps, O=ChemSearch, L=India, C=IN"
fi

echo "== sign"
"$BT/apksigner" sign --ks "$KS" \
  --ks-pass pass:chemsearch --key-pass pass:chemsearch \
  --v1-signing-enabled true --v2-signing-enabled true \
  --out "$AND/ChemSearch-$VERSION_NAME.apk" build/aligned.apk

"$BT/apksigner" verify --print-certs "$AND/ChemSearch-$VERSION_NAME.apk" | head -3
ls -la "$AND/ChemSearch-$VERSION_NAME.apk"
