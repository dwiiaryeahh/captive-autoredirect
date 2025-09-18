#!/bin/bash
#
# This script installs all necessary dependencies for the captive portal projects.

# Set color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to install dependencies in a directory
install_deps() {
  DIR=$1
  echo -e "\n${YELLOW}Navigating to ${DIR}...${NC}"
  if [ -d "$DIR" ]; then
    cd "$DIR"
    if [ -f "package.json" ]; then
      echo -e "${GREEN}Installing dependencies for ${DIR}...${NC}"
      npm install
    else
      echo "No package.json found in ${DIR}, skipping."
    fi
    cd ..
  else
    echo "Directory ${DIR} not found, skipping."
  fi
}

# Install for all projects
install_deps "facebook"
install_deps "instagram"
install_deps "x"
install_deps "default-captive"

echo -e "\n${GREEN}✅ Setup complete. All dependencies are installed.${NC}"
