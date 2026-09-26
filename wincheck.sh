#!/bin/sh
echo "=== Named top-level windows on :99 ==="
xwininfo -root -children -display :99 2>/dev/null | grep '"' | grep -v 'has no name'
echo "=== End ==="
