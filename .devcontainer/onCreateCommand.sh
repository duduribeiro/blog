#!/usr/bin/env bash

echo "Updating RubyGems..."
gem update --system -N

echo "Installing dependencies..."
bundle

echo "Done!"