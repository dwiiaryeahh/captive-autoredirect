#!/bin/bash

# This script stops all running Node.js server processes.

# Set color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Attempting to stop all Node.js servers...${NC}"

# Use pkill to gracefully terminate node processes
# Using pkill is often safer than killall as it provides more options
pkill -f "node server.js"

# Check if processes were terminated
if pgrep -f "node server.js" > /dev/null; then
    echo -e "Could not stop all servers gracefully. Forcing shutdown..."
    killall -9 node
fi

echo -e "${GREEN}✅ All Node.js server processes have been stopped.${NC}"
