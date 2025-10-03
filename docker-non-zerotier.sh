#!/bin/bash

# GenieACS Docker Simple Installer
# Basic Docker installation without ZeroTier
# Version: 1.0

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration variables
INSTALL_DIR="/opt/genieacs-docker"
DATA_DIR="/opt/genieacs-docker/data"
LOG_FILE="/var/log/genieacs-docker-install.log"

# Function to run command with progress
run_command() {
    local cmd="$1"
    local msg="$2"
    printf "${YELLOW}%-60s${NC}" "$msg..."

    # Execute command with better error handling
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}Done${NC}"
        return 0
    else
        local exit_code=$?
        echo -e "${RED}Failed${NC}"
        echo -e "${RED}Command failed with exit code: $exit_code${NC}"

        # Show last few lines of log for debugging
        if [ -f "$LOG_FILE" ]; then
            echo -e "${YELLOW}Last few lines from log:${NC}"
            tail -n 5 "$LOG_FILE" 2>/dev/null || echo "Could not read log file"
            echo -e "${RED}Full log available at: $LOG_FILE${NC}"
        fi

        exit 1
    fi
}

# Print banner
print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "   ____            _        ____            _     _        "
    echo "  / ___|  ___ _ __(_) ___  |  _ \  ___   ___| | __(_)_ __   "
    echo " | |  _  / _ \ '__| |/ _ \ | | | |/ _ \ / __| |/ /| | '_ \  "
    echo " | |_| ||  __/ |  | |  __/ | |_| | (_) | (__|   < | | |_) | "
    echo "  \____| \___|_|  |_|\___| |____/ \___/ \___|_|\_\|_| .__/  "
    echo "                                                   |_|     "
    echo ""
    echo "              GenieACS Docker Simple Installer"
    echo "                  (Without ZeroTier Support)"
    echo -e "${NC}"
}

# Check for root access
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi

    # Check if we can write to common directories
    for dir in "/var/log" "/opt" "/usr/local/bin"; do
        if [ ! -w "$dir" ]; then
            echo -e "${RED}Cannot write to $dir - permission issue${NC}"
            exit 1
        fi
    done
}

# Detect OS and version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}Cannot detect OS version${NC}"
        exit 1
    fi

    echo -e "${CYAN}Detected OS: $OS $VER${NC}"

    case $OS in
        ubuntu|debian)
            PACKAGE_MANAGER="apt-get"
            ;;
        centos|rhel|fedora)
            PACKAGE_MANAGER="yum"
            ;;
        *)
            echo -e "${YELLOW}Warning: Untested OS. Proceeding with apt-get...${NC}"
            PACKAGE_MANAGER="apt-get"
            ;;
    esac
}

# Install Docker and Docker Compose
install_docker() {
    if command -v docker > /dev/null 2>&1 && command -v docker-compose > /dev/null 2>&1; then
        echo -e "${GREEN}Docker and Docker Compose already installed${NC}"
        docker --version
        docker-compose --version
        return
    fi

    echo -e "\n${MAGENTA}${BOLD}Installing Docker...${NC}\n"

    case $PACKAGE_MANAGER in
        apt-get)
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y apt-transport-https ca-certificates curl gnupg lsb-release" "Installing dependencies"

            # Remove old Docker GPG key if exists
            run_command "rm -f /usr/share/keyrings/docker-archive-keyring.gpg" "Cleaning old Docker keys"

            run_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "Adding Docker GPG key"
            run_command "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null" "Adding Docker repository"
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Installing Docker"
            ;;
        yum)
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y yum-utils" "Installing yum-utils"
            run_command "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo" "Adding Docker repository"
            run_command "$PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Installing Docker"
            ;;
    esac

    run_command "systemctl start docker" "Starting Docker service"
    run_command "systemctl enable docker" "Enabling Docker service"

    # Install docker-compose if not available
    if ! command -v docker-compose > /dev/null 2>&1; then
        run_command "curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose" "Installing Docker Compose"
        run_command "chmod +x /usr/local/bin/docker-compose" "Setting Docker Compose permissions"
    fi

    echo -e "${GREEN}Docker installation completed${NC}"
    docker --version
    docker-compose --version
}

# Setup directories
setup_directories() {
    echo -e "\n${MAGENTA}${BOLD}Setting up directories...${NC}\n"

    run_command "mkdir -p $INSTALL_DIR" "Creating installation directory"
    run_command "mkdir -p $DATA_DIR/{mongodb,logs,ext}" "Creating data directories"
    run_command "chmod -R 755 $INSTALL_DIR" "Setting directory permissions"
}

# Copy files to installation directory
copy_files() {
    echo -e "\n${MAGENTA}${BOLD}Copying GenieACS files...${NC}\n"

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    run_command "cp $script_dir/docker-compose.yml $INSTALL_DIR/" "Copying docker-compose.yml"
    run_command "cp $script_dir/Dockerfile $INSTALL_DIR/" "Copying Dockerfile"
    run_command "cp $script_dir/entrypoint.sh $INSTALL_DIR/" "Copying entrypoint.sh"
    run_command "cp $script_dir/supervisord.conf $INSTALL_DIR/" "Copying supervisord.conf"
    run_command "cp -r $script_dir/config $INSTALL_DIR/" "Copying config directory"

    # Make entrypoint executable
    run_command "chmod +x $INSTALL_DIR/entrypoint.sh" "Setting executable permissions"
}

# Create environment file
create_env_file() {
    echo -e "\n${MAGENTA}${BOLD}Creating environment configuration...${NC}\n"

    cat > "$INSTALL_DIR/.env" << EOF
# GenieACS Docker Environment Configuration

# Data directory
DATA_DIR=$DATA_DIR

# Timezone
TZ=Asia/Jakarta

# GenieACS Interface Configuration
GENIEACS_CWMP_INTERFACE=0.0.0.0
GENIEACS_NBI_INTERFACE=0.0.0.0
GENIEACS_FS_INTERFACE=0.0.0.0
GENIEACS_UI_INTERFACE=0.0.0.0

# MongoDB Configuration
MONGO_DATA_DIR=/data/db

# ZeroTier (not used in simple version)
ZEROTIER_NETWORK_ID=

# Extension directory (optional)
GENIEACS_EXT_HOST_DIR=./ext
EOF

    echo -e "${GREEN}.env file created at $INSTALL_DIR/.env${NC}"
}

# Build and start Docker containers
build_and_start() {
    echo -e "\n${MAGENTA}${BOLD}Building and starting GenieACS...${NC}\n"

    cd "$INSTALL_DIR" || exit 1

    run_command "docker-compose build --no-cache" "Building Docker image"
    run_command "docker-compose up -d" "Starting containers"

    echo -e "\n${CYAN}Waiting for services to be ready...${NC}"
    sleep 10

    # Check container status
    if docker ps | grep -q genieacs-server; then
        echo -e "${GREEN}GenieACS container is running${NC}"
    else
        echo -e "${RED}GenieACS container failed to start${NC}"
        echo -e "${YELLOW}Check logs with: docker logs genieacs-server${NC}"
        exit 1
    fi
}

# Display final information
show_info() {
    echo -e "\n${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}   GenieACS Installation Completed Successfully!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}\n"

    # Get server IP
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')

    echo -e "${CYAN}Installation Details:${NC}"
    echo -e "  Installation Directory: ${YELLOW}$INSTALL_DIR${NC}"
    echo -e "  Data Directory: ${YELLOW}$DATA_DIR${NC}"
    echo -e "  Log File: ${YELLOW}$LOG_FILE${NC}"

    echo -e "\n${CYAN}GenieACS Services:${NC}"
    echo -e "  Web UI:        ${GREEN}http://$server_ip:3000${NC}"
    echo -e "  CWMP (TR-069): ${GREEN}http://$server_ip:7547${NC}"
    echo -e "  NBI API:       ${GREEN}http://$server_ip:7557${NC}"
    echo -e "  File Server:   ${GREEN}http://$server_ip:7567${NC}"

    echo -e "\n${CYAN}Useful Commands:${NC}"
    echo -e "  View logs:           ${YELLOW}docker logs genieacs-server${NC}"
    echo -e "  Follow logs:         ${YELLOW}docker logs -f genieacs-server${NC}"
    echo -e "  Restart container:   ${YELLOW}cd $INSTALL_DIR && docker-compose restart${NC}"
    echo -e "  Stop container:      ${YELLOW}cd $INSTALL_DIR && docker-compose down${NC}"
    echo -e "  Start container:     ${YELLOW}cd $INSTALL_DIR && docker-compose up -d${NC}"
    echo -e "  Service status:      ${YELLOW}docker exec genieacs-server supervisorctl status${NC}"
    echo -e "  Access MongoDB:      ${YELLOW}docker exec -it genieacs-server mongo genieacs${NC}"

    echo -e "\n${CYAN}Next Steps:${NC}"
    echo -e "  1. Access Web UI at: ${GREEN}http://$server_ip:3000${NC}"
    echo -e "  2. Default credentials: ${YELLOW}admin / admin${NC}"
    echo -e "  3. To install parameters, see: ${YELLOW}parameter/README.md${NC}"

    echo -e "\n${YELLOW}Note: Make sure ports 3000, 7547, 7557, 7567 are accessible${NC}"
    echo -e "${YELLOW}      through your firewall if accessing remotely.${NC}\n"
}

# Main execution
main() {
    # Clear screen
    clear

    # Print banner
    print_banner

    # Check root access
    check_root

    # Detect OS
    detect_os

    # Install Docker
    install_docker

    # Setup directories
    setup_directories

    # Copy files
    copy_files

    # Create environment file
    create_env_file

    # Build and start
    build_and_start

    # Show final information
    show_info

    echo -e "${GREEN}${BOLD}Installation completed successfully!${NC}\n"
}

# Run main function
main
