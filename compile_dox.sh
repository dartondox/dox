#!/bin/bash

PUBSPEC_FILE="packages/dox-cli/pubspec.yaml"
VERSION_FILE="packages/dox-cli/lib/src/version.dart"

# Check if pubspec.yaml exists
if [ ! -f "$PUBSPEC_FILE" ]; then
    echo "Error: $PUBSPEC_FILE not found"
    exit 1
fi

# Extract version from pubspec.yaml
VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version:[[:space:]]*//' | tr -d '"' | tr -d "'")

# Check if version was found
if [ -z "$VERSION" ]; then
    echo "Error: Could not find version in $PUBSPEC_FILE"
    exit 1
fi

# Update the version.dart file
echo "const version = '$VERSION';" > "$VERSION_FILE"
echo "Updated $VERSION_FILE with version: $VERSION"

dart compile exe packages/dox-cli/bin/dox.dart -o packages/dox-cli/bin/dox
rm -rf packages/dox-app/bin/dox
cp packages/dox-cli/bin/dox packages/dox-app/bin/dox
