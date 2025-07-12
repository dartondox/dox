#!/bin/bash

# Script to update version numbers in all package pubspec.yaml files
# based on the version from the base pubspec.yaml

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting version update process...${NC}"

# Check if base pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found in current directory${NC}"
    exit 1
fi

# Extract version from base pubspec.yaml
echo -e "${YELLOW}Extracting version from base pubspec.yaml...${NC}"
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
echo -e "${GREEN}Found version: ${VERSION}${NC}"

# Check if version was found
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Could not extract version from pubspec.yaml${NC}"
    exit 1
fi

# Check if packages directory exists
if [ ! -d "packages" ]; then
    echo -e "${RED}Error: packages directory not found${NC}"
    exit 1
fi

# Counter for updated files
UPDATED_COUNT=0

# Find all pubspec.yaml files in packages directory
echo -e "${YELLOW}Updating package versions...${NC}"
for pubspec_file in packages/*/pubspec.yaml; do
    if [ -f "$pubspec_file" ]; then
        echo -e "${YELLOW}Processing: $pubspec_file${NC}"
        
        # Create a backup of the original file
        cp "$pubspec_file" "${pubspec_file}.backup"
        
        # Update the version line using sed
        # This will replace the version line while preserving the rest of the file
        sed -i.bak "s/^version: .*/version: $VERSION/" "$pubspec_file"
        
        # Remove the temporary .bak file created by sed
        rm "${pubspec_file}.bak"
        
        echo -e "${GREEN}✓ Updated: $pubspec_file${NC}"
        ((UPDATED_COUNT++))
    fi
done

echo -e "${GREEN}Version update completed!${NC}"
echo -e "${GREEN}Updated $UPDATED_COUNT package(s) to version $VERSION${NC}"

# Optional: Show summary of changes
echo -e "${YELLOW}Summary of changes:${NC}"
for pubspec_file in packages/*/pubspec.yaml; do
    if [ -f "$pubspec_file" ]; then
        PACKAGE_NAME=$(grep "^name:" "$pubspec_file" | sed 's/name: //' | tr -d ' ')
        CURRENT_VERSION=$(grep "^version:" "$pubspec_file" | sed 's/version: //' | tr -d ' ')
        echo -e "  ${PACKAGE_NAME}: ${CURRENT_VERSION}"
    fi
done

# update dox-cli version
DOX_CLI_VERSION_FILE="packages/dox-cli/lib/src/version.dart"
echo "const version = '$VERSION';" > "$DOX_CLI_VERSION_FILE"

echo -e "${GREEN}All package versions have been synchronized with the base version!${NC}" 

# compile dox-cli
echo -e "${YELLOW}Compiling Dox CLI...${GREEN}"
dart compile exe packages/dox-cli/bin/dox.dart -o packages/dox-cli/bin/dox
rm -rf packages/dox-app/bin/dox
cp packages/dox-cli/bin/dox packages/dox-app/bin/dox
