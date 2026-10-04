#!/usr/bin/env bash

exit_code=0
service='nginx'

if systemctl is-active --quiet "$service"; then
    echo "OK: $service is running"
else
    echo "ERROR: $service is not active"
    exit_code=1
fi

disk_usage=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
disk_limit=80

if [[ "$disk_usage" =~ ^[0-9]+$ ]]; then
    if [ "$disk_usage" -ge "$disk_limit" ]; then
        echo "ERROR: root filesystem usage is $disk_usage%"
        exit_code=1
    else
        echo "OK: root filesystem usage is $disk_usage%"
    fi
else
    echo "ERROR: invalid disk usage"
    exit_code=1
fi

memory_usage=$(LC_ALL=C free -m | awk '$1 == "Mem:" {print int(($2 - $7) / $2 * 100)}')
memory_limit=80

if [[ "$memory_usage" =~ ^[0-9]+$ ]]; then
    if [ "$memory_usage" -ge "$memory_limit" ]; then
        echo "ERROR: memory usage is $memory_usage%"
        exit_code=1
    else
        echo "OK: memory usage is $memory_usage%"
    fi
else
    echo "ERROR: invalid memory usage"
    exit_code=1
fi

ping_target='1.1.1.1'

if ping -n -c 1 -W 2 "$ping_target" >/dev/null 2>&1; then
    echo "OK: $ping_target responds to ICMP"
else
    echo "ERROR: ICMP check failed for $ping_target"
    exit_code=1
fi

exit "$exit_code"
