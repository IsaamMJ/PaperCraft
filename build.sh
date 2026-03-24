#!/bin/bash

# Install Flutter
git clone https://github.com/flutter/flutter.git ~/flutter
export PATH="$PATH:~/flutter/bin"

# Enable web support
flutter config --enable-web

# Get dependencies
flutter pub get

# Build web app without service worker caching (prevents stale deploys)
flutter build web --pwa-strategy=none --dart-define=ENV=$ENV --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_KEY=$SUPABASE_KEY --dart-define=API_BASE_URL=$API_BASE_URL --verbose 2>&1

# Copy self-destructing service worker to build output.
# This replaces any old cached service worker in users' browsers,
# clears all caches, unregisters itself, and reloads the page.
cp web/flutter_service_worker.js build/web/flutter_service_worker.js