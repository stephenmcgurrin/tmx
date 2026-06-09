#!/bin/sh
# Copy tmx from this repo to ~/bin for development testing
cp "$(cd "$(dirname "$0")" && pwd)/tmx" ~/bin/tmx && chmod +x ~/bin/tmx
