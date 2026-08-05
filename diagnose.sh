#!/bin/bash
#
# TruthPulse ビルド診断
#
# 使い方:
#   cd ~/Desktop/ws/claude/lie_checker
#   bash diagnose.sh
#
# 出力をそのままコピーして貼り付けてください。

cd "$(dirname "$0")" || exit 1

echo "=========================================="
echo " 1. 環境"
echo "=========================================="
xcodebuild -version
echo "Swift:"
swift --version 2>&1 | head -2

echo
echo "=========================================="
echo " 2. エラー（ファイル名:行番号:列番号 付き）"
echo "=========================================="
xcodebuild \
  -project TruthPulse.xcodeproj \
  -scheme TruthPulse \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build 2>&1 \
  | grep -E "error:" \
  | sed 's|.*/TruthPulse/|TruthPulse/|' \
  | sort -u \
  | head -30

echo
echo "=========================================="
echo " 3. 型チェックが遅い関数・式（300ms 超）"
echo "=========================================="
echo "※ ここに出た行が犯人です。少し時間がかかります…"
echo

xcodebuild \
  -project TruthPulse.xcodeproj \
  -scheme TruthPulse \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  OTHER_SWIFT_FLAGS='-Xfrontend -warn-long-function-bodies=300 -Xfrontend -warn-long-expression-type-checking=300' \
  build 2>&1 \
  | grep -E "took [0-9]+ms" \
  | sed 's|.*/TruthPulse/|TruthPulse/|' \
  | sort -u \
  | head -40

echo
echo "=========================================="
echo " 診断おわり"
echo "=========================================="
