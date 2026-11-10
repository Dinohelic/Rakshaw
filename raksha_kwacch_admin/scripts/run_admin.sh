#!/usr/bin/env bash
# Raksha Kawach — SGT University Transport Safety and Management System
# One-Click Flutter Web Runner for Mac / Terminal

set -e

# Determine directory structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/pubspec.yaml" ]; then
  PROJECT_DIR="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../pubspec.yaml" ]; then
  PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -d "$SCRIPT_DIR/../raksha_kwacch_admin" ]; then
  PROJECT_DIR="$(cd "$SCRIPT_DIR/../raksha_kwacch_admin" && pwd)"
elif [ -d "$SCRIPT_DIR/raksha_kwacch_admin" ]; then
  PROJECT_DIR="$(cd "$SCRIPT_DIR/raksha_kwacch_admin" && pwd)"
else
  PROJECT_DIR="$(pwd)"
fi

cd "$PROJECT_DIR"

CONFIG_FILE="config/dev.json"
EXAMPLE_FILE="config/dev.example.json"

echo "================================================================="
echo "🛡️  Raksha Kawach Admin Portal — SGT University Transport Safety"
echo "================================================================="

# Ensure local dev.json exists
if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$EXAMPLE_FILE" ]; then
    echo "ℹ️  $CONFIG_FILE not found. Creating from $EXAMPLE_FILE template..."
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "✅ Created $CONFIG_FILE."
    echo "💡 Note: Edit $CONFIG_FILE with your public SUPABASE_ANON_KEY to enable Live Hardware mode."
  else
    echo "⚠️  Template $EXAMPLE_FILE not found."
  fi
fi

# Run Flutter Web with dev.json if present
if [ -f "$CONFIG_FILE" ]; then
  echo "🔑 Using configuration: $CONFIG_FILE"
  echo "🌐 Launching Chrome with --dart-define-from-file=$CONFIG_FILE..."
  flutter run -d chrome --dart-define-from-file="$CONFIG_FILE" "$@"
else
  echo "🚀 Launching Chrome in Demo Mode fallback..."
  flutter run -d chrome "$@"
fi

