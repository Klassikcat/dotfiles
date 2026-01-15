#!/bin/bash

# GPU monitoring script for Waybar
# Supports NVIDIA GPUs

if command -v nvidia-smi &> /dev/null; then
    # Get GPU utilization and temperature
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1)
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
    GPU_MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -n1)
    GPU_MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    
    # Calculate memory percentage
    GPU_MEM_PERCENT=$(awk "BEGIN {printf \"%.0f\", ($GPU_MEM_USED/$GPU_MEM_TOTAL)*100}")
    
    # Format output
    echo "${GPU_UTIL}% ${GPU_TEMP}°C"
    echo "${GPU_UTIL}% ${GPU_TEMP}°C ${GPU_MEM_PERCENT}%"
    
    # Color based on utilization
    if [ "$GPU_UTIL" -gt 80 ]; then
        echo "critical"
    elif [ "$GPU_UTIL" -gt 50 ]; then
        echo "warning"
    else
        echo "normal"
    fi
else
    echo "N/A"
    echo "GPU not detected"
    echo "none"
fi
