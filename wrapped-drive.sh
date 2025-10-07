#!/bin/bash
# WARNING: Destructive test
# Usage: sudo ./check_wrap.sh /dev/sdX

echo "⚠️ WARNING: This test will WRITE to the last sector of the disk."
echo "Any existing data in that sector may be CORRUPTED or LOST!"
echo "Proceeding may destroy data. Make sure you have backups."

read -p "Type YES to continue, anything else to abort: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted. No data was written."
    exit 1
fi


REQUIRED_CMDS=("smartctl" "dd" "awk")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done



DISK="$1"

BLOCK_SIZE=$(cat /sys/block/$(basename $DISK)/queue/logical_block_size)

# BLOCK_SIZE=512  # bytes, 1 sector

# Get claimed size from smartctl
CLAIMED_SIZE=$(smartctl -i "$DISK" | awk -F'bytes' '/User Capacity:/ {gsub(",","",$1); print $1}' | awk '{print $NF}')

if [ -z "$CLAIMED_SIZE" ]; then
    echo "Error: Could not determine claimed size from smartctl."
    exit 1
fi

# Calculate sector counts
TOTAL_SECTORS=$((CLAIMED_SIZE / BLOCK_SIZE))
HALF_SECTOR=$((TOTAL_SECTORS / 2))
LAST_SECTOR=$((TOTAL_SECTORS - 1))
PREV_SECTOR=$((HALF_SECTOR - 1))
NEXT_SECTOR=$((HALF_SECTOR + 1))

# Write unique pattern to last sector
echo "Writing test pattern to last sector..."
printf "WRAPTEST12345678" | dd of="$DISK" bs=$BLOCK_SIZE count=1 seek=$LAST_SECTOR conv=notrunc status=none

# Read back last sector
LAST_READ=$(dd if="$DISK" bs=$BLOCK_SIZE count=1 skip=$LAST_SECTOR status=none |hexdump -v -C)

# Read halfway sector
HALF_READ=$(dd if="$DISK" bs=$BLOCK_SIZE count=1 skip=$HALF_SECTOR status=none |hexdump -v -C)

echo "Last sector: $LAST_READ"
echo "Halfway sector: $HALF_READ"

if [ "$LAST_READ" == "$HALF_READ" ]; then
    echo "Drive is likely wrapping! Fake detected."
else
    echo "No wrap detected at halfway point. Drive may be genuine."
fi