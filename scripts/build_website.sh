#!/bin/sh
# Rebuilds style.css from scripts/website.css and the Tailwind classes
# used in the site. Run it after changing any class in the website's HTML.
# Tailwind is installed once into a temporary folder, outside the repository.
set -e
cd "$(dirname "$0")/.."

tools="${TMPDIR:-/tmp}/lociq-website-tools"
if [ ! -x "$tools/node_modules/.bin/tailwindcss" ]; then
  npm install --prefix "$tools" --no-audit --no-fund --silent tailwindcss@4 @tailwindcss/cli@4
fi

NODE_PATH="$tools/node_modules" "$tools/node_modules/.bin/tailwindcss" -i scripts/website.css -o style.css
