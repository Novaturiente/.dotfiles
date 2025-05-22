#!/bin/bash

sudo cp ./system.yaml /system.yaml

sudo akshara update

stow -t ~/ nova

sudo reboot
