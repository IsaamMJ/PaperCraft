#!/bin/bash

# Install Flutter
git clone https://github.com/flutter/flutter.git ~/flutter
export PATH="$PATH:~/flutter/bin"

# Enable web support
flutter config --enable-web

# Get dependencies
flutter pub get

# Build web app with verbose output
flutter build web --dart-define=ENV=$ENV --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_KEY=$SUPABASE_KEY --dart-define=API_BASE_URL=$API_BASE_URL --verbose 2>&1