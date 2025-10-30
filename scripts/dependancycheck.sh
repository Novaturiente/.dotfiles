#!/usr/bin/env bash

pacman -Qdq | while read pkg; do
	required=$(pacman -Qi "$pkg" | grep "^Required By" | cut -d: -f2 | xargs)
	optional=$(pacman -Qi "$pkg" | grep "^Optional For" | cut -d: -f2 | xargs)
	[[ "$required" == "None" ]] && [[ "$optional" != "None" ]] && pactree -ro "$pkg"
done
