#!/usr/bin/env bash
# 不依赖 Gradle 的直接构建脚本：aapt2 -> javac -> d8 -> zipalign -> apksigner
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="/c/Users/Administrator/AppData/Local/Android/Sdk"
BT="$SDK/build-tools/36.0.0"
AJ="$SDK/platforms/android-37.0/android.jar"
JB="/d/Android Studio/jbr/bin"
PY="/c/Users/Administrator/.workbuddy/binaries/python/versions/3.13.12/python.exe"

MIN_SDK=24
TARGET_SDK=36
VERSION_CODE=2
VERSION_NAME="1.1"
PKG="com.woyun.cues"

export JAVA_HOME="D:\\Android Studio\\jbr"

OUT="$ROOT/build"
mkdir -p "$OUT/gen" "$OUT/classes" "$OUT/dex"
# 只清理自己生成的中间产物（.class / .dex / 生成的 R.java），不做递归目录删除
find "$OUT/classes" -name '*.class' -exec rm -f {} + 2>/dev/null || true
find "$OUT/dex" -name '*.dex' -exec rm -f {} + 2>/dev/null || true
find "$OUT/gen" -name '*.java' -exec rm -f {} + 2>/dev/null || true
rm -f "$OUT/unsigned.apk" "$OUT/aligned.apk" "$OUT/base.apk" "$OUT/res.zip" 2>/dev/null || true

echo "==> [1/7] 生成 AndroidManifest"
sed "s|<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">|<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\" package=\"$PKG\">|" \
    "$ROOT/app/src/main/AndroidManifest.xml" > "$OUT/AndroidManifest.xml"
grep -q "package=\"$PKG\"" "$OUT/AndroidManifest.xml" || { echo "manifest 注入失败"; exit 1; }

echo "==> [2/7] 编译资源 (aapt2 compile)"
"$BT/aapt2.exe" compile --dir "$(cygpath -w "$ROOT/app/src/main/res")" -o "$(cygpath -w "$OUT/res.zip")"

echo "==> [3/7] 链接资源 (aapt2 link)"
"$BT/aapt2.exe" link \
    -o "$(cygpath -w "$OUT/base.apk")" \
    -I "$(cygpath -w "$AJ")" \
    --manifest "$(cygpath -w "$OUT/AndroidManifest.xml")" \
    --java "$(cygpath -w "$OUT/gen")" \
    --min-sdk-version $MIN_SDK \
    --target-sdk-version $TARGET_SDK \
    --version-code $VERSION_CODE \
    --version-name "$VERSION_NAME" \
    --no-version-vectors \
    --auto-add-overlay \
    -0 .pcm \
    "$(cygpath -w "$OUT/res.zip")"

echo "==> [4/7] 编译 Java"
find "$ROOT/app/src/main/java" "$OUT/gen" -name '*.java' | while read -r f; do cygpath -m "$f"; done > "$OUT/sources.txt"
"$JB/javac.exe" --release 17 -encoding UTF-8 -nowarn \
    -classpath "$(cygpath -m "$AJ")" \
    -d "$(cygpath -m "$OUT/classes")" "@$(cygpath -m "$OUT/sources.txt")"

echo "==> [5/7] R8 混淆加固 + 转换 DEX"
"$JB/jar.exe" cf "$(cygpath -m "$OUT/classes.jar")" -C "$(cygpath -m "$OUT/classes")" .
"$JB/java.exe" -cp "$(cygpath -m "$ROOT/tools/r8.jar")" com.android.tools.r8.R8 \
    --release --min-api $MIN_SDK --lib "$(cygpath -m "$AJ")" \
    --output "$(cygpath -m "$OUT/dex")" \
    --pg-conf "$(cygpath -m "$ROOT/tools/proguard.txt")" \
    "$(cygpath -m "$OUT/classes.jar")"
# R8 把 -printmapping 写到 proguard.txt 所在目录（tools/build/），归位到 build/
if [ -f "$ROOT/tools/build/mapping.txt" ]; then
    cp "$ROOT/tools/build/mapping.txt" "$(cygpath -m "$OUT/mapping.txt")"
fi
echo "   混淆映射: $OUT/mapping.txt"

echo "==> [6/7] 打包 APK"
cp "$OUT/base.apk" "$OUT/unsigned.apk"
"$PY" - "$(cygpath -m "$OUT/unsigned.apk")" "$(cygpath -m "$OUT/dex")" <<'PYEOF'
import sys, zipfile, os
apk, dexdir = sys.argv[1], sys.argv[2]
dexs = sorted(f for f in os.listdir(dexdir) if f.endswith('.dex'))
with zipfile.ZipFile(apk, 'a', zipfile.ZIP_DEFLATED) as z:
    for d in dexs:
        z.write(os.path.join(dexdir, d), d)
print("   %d 个 dex 已写入: %s" % (len(dexs), ", ".join(dexs)))
PYEOF

"$BT/zipalign.exe" -f -p 4 "$(cygpath -w "$OUT/unsigned.apk")" "$(cygpath -w "$OUT/aligned.apk")"

echo "==> [7/7] 签名"
KS="$ROOT/keystore/woyun.jks"
mkdir -p "$ROOT/keystore"
if [ ! -f "$KS" ]; then
    "$JB/keytool.exe" -genkeypair -v \
        -keystore "$(cygpath -m "$KS")" -storepass woyun123 -keypass woyun123 \
        -alias woyun -keyalg RSA -keysize 2048 -validity 10950 \
        -dname "CN=WoYun, OU=App, O=WoYun, L=CN, ST=CN, C=CN" >/dev/null
    echo "   已生成签名密钥 keystore/woyun.jks"
fi

"$BT/apksigner.bat" sign \
    --ks "$(cygpath -m "$KS")" --ks-pass pass:woyun123 --key-pass pass:woyun123 \
    --ks-key-alias woyun \
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
    --out "$(cygpath -m "$ROOT/我晕.apk")" \
    "$(cygpath -m "$OUT/aligned.apk")" 2>&1 | grep -v "^WARNING: " || true

"$BT/apksigner.bat" verify --print-certs "$(cygpath -m "$ROOT/我晕.apk")" 2>&1 | grep -v "^WARNING: " | head -5

echo ""
echo "构建完成: $ROOT/我晕.apk"
ls -lh "$ROOT/我晕.apk"
