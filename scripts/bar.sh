#!/bin/bash

killall ags && ags -c /usr/share/sleex/config.js &
sleep 0.1
ags run-js 'cycleMode();'
ags run-js 'cycleMode();'
