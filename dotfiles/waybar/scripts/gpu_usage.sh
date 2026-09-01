#!/usr/bin/env bash
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo "0"
else
    echo "0"
fi
