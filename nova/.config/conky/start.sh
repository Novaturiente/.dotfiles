#!/bin/bash

killall conky

sleep 1

cd $HOME/.config/conky/auzia-conky/

conky -c conkyrc &> /dev/null &

sleep 1

cd ..

conky -c $HOME/.config/conky/sysinfo_conky.conf &> /dev/null &
