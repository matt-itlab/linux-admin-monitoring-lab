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

exit "$exit_code"
