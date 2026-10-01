#!/bin/sh
# Rebuild rpiv-todo / rpiv-ask-user-question single-file bundles (loaded via settings.json "extensions").
# Run after `pi update` touches these packages: npm reinstall deletes the bundles and pi fails to load them.
# Bundle must sit at package root: registerLocalesFromDir resolves locales/ from import.meta.url.
set -e
cd ~/.pi/agent/npm/node_modules/@juicesharp
for p in rpiv-todo rpiv-ask-user-question; do
  bun build $p/index.ts --target=node --format=esm --outfile=$p/index.bundle.mjs \
    --external '@earendil-works/*' --external typebox --external 'typebox/*' --external '@juicesharp/*'
done
