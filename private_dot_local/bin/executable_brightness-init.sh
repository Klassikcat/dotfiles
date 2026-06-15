#!/bin/bash

# 현재 시각
NOW_TS=$(date +%s)
TODAY=$(date +%Y-%m-%d)
if HELIOCRON=$(command -v heliocron 2>/dev/null); then
    :
elif [ -x "$HOME/.local/bin/heliocron" ]; then
    HELIOCRON="$HOME/.local/bin/heliocron"
elif [ -x "$HOME/.cargo/bin/heliocron" ]; then
    HELIOCRON="$HOME/.cargo/bin/heliocron"
else
    echo "Error: heliocron executable not found." >&2
    exit 127
fi
LAT="37.56"
LON="126.97"

# Heliocron Report에서 시간 파싱
REPORT=$($HELIOCRON --latitude $LAT --longitude $LON --date "$TODAY" report --json)

SUNRISE_ISO=$(echo "$REPORT" | grep -o '"sunrise":"[^"]*"' | cut -d'"' -f4)
MIDNIGHT_TS=$(date -d "$TODAY 00:00:00" +%s)
SUNRISE_TS=$(date -d "$SUNRISE_ISO" +%s)

# 자정(00:00) ~ 일출: 30% (어두운 밤)
# 일출 ~ 자정: 100% (낮)
if [ $NOW_TS -ge $MIDNIGHT_TS ] && [ $NOW_TS -lt $SUNRISE_TS ]; then
    $HOME/.local/bin/brightness 30
else
    $HOME/.local/bin/brightness 100
fi
