#!/bin/bash

MIC_ID=$(wpctl status | awk '/USB Audio Microphone/{print $3}' | tr -d '.')

if [[ -n "$MIC_ID" ]]; then
    wpctl set-volume "$MIC_ID" 1.4
fi
