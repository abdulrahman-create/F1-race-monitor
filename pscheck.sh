#!/bin/sh
for p in /proc/[0-9]*; do
  pid="${p##*/}"
  comm="$(cat "$p/comm" 2>/dev/null)"
  echo "PID $pid: $comm"
done
