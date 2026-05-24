#!/bin/bash

# 1. 사용자 수동 고정 모드면 바로 적용하고 종료
if [ -f "$HOME/.cache/prefered-theme" ]; then
    THEME=$(cat "$HOME/.cache/prefered-theme" | tr '[:upper:]' '[:lower:]')
    $HOME/.local/bin/toggle-theme "$THEME"
    exit 0
fi

# 2. 현재 시각
NOW_TS=$(date +%s)
TODAY=$(date +%Y-%m-%d)
HELIOCRON="$HOME/.cargo/bin/heliocron"
LAT="37.56"
LON="126.97"

# 3. Heliocron Report에서 시간 파싱 (JSON 없이 grep 사용)
# 출력 예시에서 시간만 뽑아서 Timestamp로 변환
# "sunrise":"2025-11-23T07:20:10+09:00" 형태이므로 sed로 추출
REPORT=$($HELIOCRON --latitude $LAT --longitude $LON --date "$TODAY" report --json)

# 파싱: 정규식으로 시간 추출 (ISO8601 포맷)
SUNRISE_ISO=$(echo "$REPORT" | grep -o '"sunrise":"[^"]*"' | cut -d'"' -f4)
SUNSET_ISO=$(echo "$REPORT" | grep -o '"sunset":"[^"]*"' | cut -d'"' -f4)

# date 명령어로 Timestamp 변환
SUNRISE_TS=$(date -d "$SUNRISE_ISO" +%s)
SUNSET_TS=$(date -d "$SUNSET_ISO" +%s)
MIDNIGHT_TS=$(date -d "$TODAY 00:00:00" +%s)

# 4. 비교 로직
if [ $NOW_TS -ge $MIDNIGHT_TS ] && [ $NOW_TS -lt $SUNRISE_TS ]; then
    # 00:00 ~ 일출 전: Midnight
    TARGET="midnight"
elif [ $NOW_TS -ge $SUNRISE_TS ] && [ $NOW_TS -lt $SUNSET_TS ]; then
    # 일출 ~ 일몰: Light
    TARGET="light"
else
    # 일몰 ~ 자정: Dark
    TARGET="dark"
fi

# 5. 적용 (system 모드로)
$HOME/.local/bin/toggle-theme "$TARGET" system
