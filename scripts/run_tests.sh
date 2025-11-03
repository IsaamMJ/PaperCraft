#!/bin/bash

# Papercraft Test Runner Script
# Runs all unit tests, widget tests, and generates coverage report

set -e

echo "=================================="
echo "Papercraft Test Suite"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter not found in PATH${NC}"
    exit 1
fi

# Get project root directory
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}Project Root: $PROJECT_ROOT${NC}"
echo ""

# Step 1: Get dependencies
echo -e "${YELLOW}Step 1: Getting dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✓ Dependencies updated${NC}"
echo ""

# Step 2: Run analyzer
echo -e "${YELLOW}Step 2: Running Dart analyzer...${NC}"
dart analyze lib/
ANALYZE_EXIT=$?
if [ $ANALYZE_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ Analyzer: PASSED${NC}"
else
    echo -e "${RED}✗ Analyzer: FAILED${NC}"
fi
echo ""

# Step 3: Run unit tests
echo -e "${YELLOW}Step 3: Running unit tests...${NC}"
flutter test test/features/ --coverage
UNIT_TEST_EXIT=$?
if [ $UNIT_TEST_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ Unit Tests: PASSED${NC}"
else
    echo -e "${RED}✗ Unit Tests: FAILED${NC}"
fi
echo ""

# Step 4: Generate coverage report (if lcov is installed)
if command -v lcov &> /dev/null; then
    echo -e "${YELLOW}Step 4: Generating coverage report...${NC}"
    lcov --summary coverage/lcov.info 2>/dev/null || echo "Coverage report generated at coverage/lcov.info"
    echo -e "${GREEN}✓ Coverage report ready${NC}"
else
    echo -e "${YELLOW}Step 4: Skipping coverage report (lcov not installed)${NC}"
fi
echo ""

# Step 5: Summary
echo "=================================="
echo "Test Summary"
echo "=================================="

if [ $ANALYZE_EXIT -eq 0 ] && [ $UNIT_TEST_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Run: flutter test test/integration/ (for integration tests)"
    echo "  - Run: flutter build apk --release (to build app)"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. See details above.${NC}"
    exit 1
fi
