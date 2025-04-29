#!/bin/bash

killall conky

sleep 1

conky -c $HOME/.config/conky/sysinfo_conky.conf &> /dev/null &

cd $HOME/.config/conky/auzia-conky/

conky -c conkyrc &> /dev/null &



