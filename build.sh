#!/bin/bash

# Install Flutter
git clone https://github.com/flutter/flutter.git ~/flutter
export PATH="$PATH:~/flutter/bin"

# Enable web support
flutter config --enable-web

# Get dependencies
flutter pub get

# Build web app
flutter build web --dart-define=ENV=$ENV --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_KEY=$SUPABASE_KEY --dart-define=API_BASE_URL=$API_BASE_URL --dart-define=GROQ_API_KEY=$GROQ_API_KEY --verbose 2>&1

# Replace the Flutter-generated service worker with a self-destructing one.
# This clears all old caches in users' browsers and unregisters the service worker,
# ensuring users always get the latest deploy.
cp -f web/flutter_service_worker.js build/web/flutter_service_worker.js
echo "Replaced flutter_service_worker.js with self-destructing version"