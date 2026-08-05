#!/bin/bash

launchctl unload ~/Library/LaunchAgents/com.totomz.calsync.plist || true
rm -f ~/Library/LaunchAgents/com.totomz.calsync.plist  || true

#mkdir -p ~/.calsync  || true
rm /Users/totomz/Documents/totomz/calsyn/calsync.py || true
rm /Users/totomz/Documents/totomz/calsyn/com.totomz.calsync.plist || true

cp /Users/totomz/Documents/totomz/calsyn/calsync.py ~/.calsync/
cp /Users/totomz/Documents/totomz/calsyn/com.totomz.calsync.plist ~/Library/LaunchAgents/

launchctl load ~/Library/LaunchAgents/com.totomz.calsync.plist