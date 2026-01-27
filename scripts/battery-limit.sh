#!/bin/bash
# Battery charge limiter for Lenovo IdeaPad
# Enables conservation mode at >=80%, disables at <=50%

BATTERY="/sys/class/power_supply/BAT1/capacity"
CONSERVATION="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

if [[ ! -f "$BATTERY" ]] || [[ ! -f "$CONSERVATION" ]]; then
    echo "Error: Required sysfs files not found"
    exit 1
fi

capacity=$(cat "$BATTERY")
current_mode=$(cat "$CONSERVATION")

if [[ "$capacity" -ge 75 && "$current_mode" -eq 0 ]]; then
    echo 1 >"$CONSERVATION"
    echo "Battery at ${capacity}% - enabled conservation mode"
elif [[ "$capacity" -le 70 && "$current_mode" -eq 1 ]]; then
    echo 0 >"$CONSERVATION"
    echo "Battery at ${capacity}% - disabled conservation mode"
else
    echo "Battery at ${capacity}% - conservation mode: $current_mode (no change)"
fi
