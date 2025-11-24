#!/bin/bash

# CI Validation Script
# This script runs all the CI checks locally before committing code
# It mirrors the checks performed in .github/workflows/ci.yml

echo "=================================="
echo "Running CI Validation Checks"
echo "=================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Track overall success
OVERALL_SUCCESS=true

# Function to print colored status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2 passed${NC}"
    else
        echo -e "${RED}✗ $2 failed${NC}"
        OVERALL_SUCCESS=false
    fi
}

# 1. Get Flutter dependencies
echo "Step 1: Getting Flutter dependencies..."
flutter pub get
print_status $? "Flutter pub get"
echo ""

# 2. Run code analysis
echo "Step 2: Running code analysis..."
flutter analyze
ANALYZE_RESULT=$?
print_status $ANALYZE_RESULT "Flutter analyze"
echo ""

# 3. Run tests
echo "Step 3: Running tests..."
flutter test
TEST_RESULT=$?
print_status $TEST_RESULT "Flutter test"
echo ""

# 4. Check code formatting
echo "Step 4: Checking code formatting..."
dart format --set-exit-if-changed .
FORMAT_RESULT=$?
print_status $FORMAT_RESULT "Dart format check"
echo ""

# Print summary
echo "=================================="
echo "CI Validation Summary"
echo "=================================="
if [ "$OVERALL_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ All CI checks passed!${NC}"
    echo ""
    echo "Your code is ready to be committed and pushed."
    exit 0
else
    echo -e "${RED}✗ Some CI checks failed${NC}"
    echo ""
    echo "Please fix the issues above before committing."
    exit 1
fi
