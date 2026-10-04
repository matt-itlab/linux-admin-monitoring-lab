#!/usr/bin/env bash

service='nginx'

if systemctl is-active --quiet "$service"; then
    echo "OK: $service is running"
    exit 0
else
    echo "ERROR: $service is not active"
    exit 1
fi
