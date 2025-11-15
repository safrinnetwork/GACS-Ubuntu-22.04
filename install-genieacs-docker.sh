#!/bin/bash

# GenieACS Docker Universal Installer
# Compatible with any VPS and ZeroTier network configuration
# Features: Full auto ZeroTier installation, network join, IP detection, improved error handling, fixed ZeroTier status, comprehensive Docker registry fixes
# Version: 1.6

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

# Function to display spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${CYAN} [%c]  ${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

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

# Function to prompt for input with default value
prompt_input() {
    local prompt="$1"
    local default="$2"
    local variable_name="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$variable_name=\"\${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$variable_name=\"$input\""
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
    echo "              GenieACS Docker Universal Installer"
    echo "                     with ZeroTier Support"
    echo -e "${NC}"
}

# Check for root access and system requirements
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
        return
    fi

    case $PACKAGE_MANAGER in
        apt-get)
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y apt-transport-https ca-certificates curl gnupg lsb-release" "Installing dependencies"
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
}

# Setup directories
setup_directories() {
    run_command "mkdir -p $INSTALL_DIR" "Creating installation directory"
    run_command "mkdir -p $DATA_DIR/{mongodb,logs,ext,zerotier}" "Creating data directories"
    run_command "chmod -R 755 $INSTALL_DIR" "Setting directory permissions"
}

# Check if ZeroTier is installed
check_zerotier_installed() {
    if command -v zerotier-cli > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Install ZeroTier
install_zerotier() {
    echo -e "\n${MAGENTA}${BOLD}Installing ZeroTier...${NC}"

    if check_zerotier_installed; then
        echo -e "${GREEN}ZeroTier is already installed${NC}"
        return 0
    fi

    echo -e "${CYAN}ZeroTier not found. Installing ZeroTier...${NC}"
    run_command "curl -s https://install.zerotier.com | bash" "Installing ZeroTier"

    # Wait for ZeroTier service to be ready
    echo -e "${CYAN}Waiting for ZeroTier service to start...${NC}"
    local timeout=30
    local counter=0

    while [ $counter -lt $timeout ]; do
        if systemctl is-active --quiet zerotier-one; then
            echo -e "${GREEN}ZeroTier service is running${NC}"
            break
        fi
        sleep 1
        counter=$((counter + 1))
    done

    if [ $counter -ge $timeout ]; then
        echo -e "${RED}ZeroTier service failed to start within $timeout seconds${NC}"
        exit 1
    fi

    # Verify installation
    if check_zerotier_installed; then
        echo -e "${GREEN}ZeroTier installed successfully${NC}"
        return 0
    else
        echo -e "${RED}ZeroTier installation failed${NC}"
        exit 1
    fi
}

# Join ZeroTier network and wait for IP
join_zerotier_network() {
    local network_id="$1"

    echo -e "\n${CYAN}Joining ZeroTier network: $network_id${NC}"

    # Join the network
    if ! zerotier-cli join "$network_id" >/dev/null 2>&1; then
        echo -e "${RED}Failed to join ZeroTier network: $network_id${NC}"
        exit 1
    fi

    echo -e "${GREEN}Successfully joined network: $network_id${NC}"
    echo -e "${YELLOW}Please authorize this device in your ZeroTier Central dashboard${NC}"
    echo -e "${YELLOW}Waiting for network authorization and IP assignment...${NC}"

    # Wait for IP address assignment
    local timeout=300  # 5 minutes
    local counter=0
    local check_interval=5

    while [ $counter -lt $timeout ]; do
        local network_info
        network_info=$(zerotier-cli listnetworks 2>/dev/null | grep "$network_id")

        if [ -n "$network_info" ]; then
            # Check if we have an IP address
            local ip_address
            ip_address=$(echo "$network_info" | awk '{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/')

            if [ -n "$ip_address" ]; then
                ZEROTIER_IP="${ip_address%/*}"  # Remove CIDR notation
                echo -e "${GREEN}ZeroTier IP assigned: $ZEROTIER_IP${NC}"
                return 0
            fi
        fi

        printf "${CYAN}.${NC}"
        sleep $check_interval
        counter=$((counter + check_interval))
    done

    echo -e "\n${RED}Timeout waiting for IP address assignment after $((timeout/60)) minutes${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo -e "  1. Device is authorized in ZeroTier Central dashboard"
    echo -e "  2. Network has available IP addresses"
    echo -e "  3. Network configuration is correct"
    echo -e "\nYou can continue with manual IP configuration or retry later."

    local choice
    read -p "Continue with installation? (y/n): " choice
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        exit 1
    fi

    ZEROTIER_IP="auto-detect"
    return 1
}

# Detect existing ZeroTier networks
detect_zerotier_networks() {
    echo -e "\n${CYAN}Detecting existing ZeroTier networks...${NC}"

    # Check if ZeroTier is installed
    if ! check_zerotier_installed; then
        echo -e "${YELLOW}ZeroTier not found.${NC}"
        return 1
    fi

    # Check if ZeroTier service is running
    if ! systemctl is-active --quiet zerotier-one; then
        echo -e "${YELLOW}ZeroTier service is not running.${NC}"
        return 1
    fi

    # Get existing networks
    local networks_output
    networks_output=$(zerotier-cli listnetworks 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$networks_output" ]; then
        echo -e "${YELLOW}No ZeroTier networks found.${NC}"
        return 1
    fi

    # Parse networks (skip header line)
    local networks_info
    networks_info=$(echo "$networks_output" | grep -v "200 listnetworks <nwid>" | grep "^200 listnetworks")

    if [ -z "$networks_info" ]; then
        echo -e "${YELLOW}No active ZeroTier networks found.${NC}"
        return 1
    fi

    return 0
}

# Display ZeroTier network selection menu
display_network_menu() {
    local networks_info="$1"
    local counter=1

    echo -e "\n${GREEN}Found existing ZeroTier networks:${NC}"
    echo -e "${CYAN}┌─────┬──────────────────┬─────────────────────┬────────────┐${NC}"
    echo -e "${CYAN}│ No. │ Network ID       │ IP Address          │ Status     │${NC}"
    echo -e "${CYAN}├─────┼──────────────────┼─────────────────────┼────────────┤${NC}"

    # Store network information for later use
    declare -g -A network_ids
    declare -g -A network_ips
    declare -g -A network_status

    while IFS= read -r line; do
        # Parse format: 200 listnetworks <network_id> <name> <mac> <status> <type> <dev> <ip/cidr>
        if [[ $line =~ ^200[[:space:]]listnetworks[[:space:]]([a-f0-9]+)[[:space:]]+([^[:space:]_]+_?[^[:space:]]*)[[:space:]]+([a-f0-9:]+)[[:space:]]+([A-Z]+)[[:space:]]+([A-Z]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9\.]+/[0-9]+) ]]; then
            local network_id="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local mac="${BASH_REMATCH[3]}"
            local status="${BASH_REMATCH[4]}"
            local type="${BASH_REMATCH[5]}"
            local dev="${BASH_REMATCH[6]}"
            local ip_cidr="${BASH_REMATCH[7]}"
            local ip_only="${ip_cidr%/*}"

            network_ids[$counter]="$network_id"
            network_ips[$counter]="$ip_only"
            network_status[$counter]="$status"

            printf "${CYAN}│ %-3s │ %-16s │ %-19s │ %-10s │${NC}\n" "$counter" "$network_id" "$ip_only" "$status"
            counter=$((counter + 1))
        fi
    done <<< "$networks_info"

    echo -e "${CYAN}└─────┴──────────────────┴─────────────────────┴────────────┘${NC}"
    echo -e "\n${CYAN}Available Options:${NC}"
    for ((i=1; i<counter; i++)); do
        echo -e "${GREEN}$i.${NC} Use existing network: ${CYAN}${network_ids[$i]}${NC} (IP: ${YELLOW}${network_ips[$i]}${NC})"
    done
    echo -e "${GREEN}$((counter-1)).${NC} Enter new Network ID manually ${YELLOW}(join a different network)${NC}"

    return $((counter-1))
}

# Get network configuration
configure_network() {
    echo -e "\n${MAGENTA}${BOLD}ZeroTier Network Configuration${NC}"

    # Check if ZeroTier is installed, if not install it automatically
    if ! check_zerotier_installed; then
        echo -e "${YELLOW}ZeroTier is not installed on this system.${NC}"
        echo -e "${CYAN}Installing ZeroTier automatically (required for GenieACS)...${NC}"

        install_zerotier
    else
        echo -e "${GREEN}ZeroTier is already installed${NC}"
    fi

    # Try to detect existing ZeroTier networks
    local networks_info
    local network_id_to_join=""

    if detect_zerotier_networks; then
        networks_info=$(zerotier-cli listnetworks 2>/dev/null | grep -v "200 listnetworks <nwid>" | grep "^200 listnetworks")

        if [ -n "$networks_info" ]; then
            display_network_menu "$networks_info"
            local max_option=$?
            local manual_option=$((max_option + 1))

            echo -e "\nSelect an option:"
            local choice
            while true; do
                read -p "Enter your choice [1-$manual_option]: " choice

                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$manual_option" ]; then
                    if [ "$choice" -eq "$manual_option" ]; then
                        # Manual entry - ask for new network ID to join
                        echo -e "\n${CYAN}Manual Network Configuration:${NC}"
                        prompt_input "Enter ZeroTier Network ID to join" "" "network_id_to_join"
                        while [ -z "$network_id_to_join" ]; do
                            echo -e "${RED}ZeroTier Network ID is required!${NC}"
                            prompt_input "Enter ZeroTier Network ID to join" "" "network_id_to_join"
                        done

                        # Join the new network and wait for IP
                        if join_zerotier_network "$network_id_to_join"; then
                            ZEROTIER_NETWORK_ID="$network_id_to_join"
                            # ZEROTIER_IP is set in join_zerotier_network function
                        else
                            ZEROTIER_NETWORK_ID="$network_id_to_join"
                            ZEROTIER_IP="auto-detect"
                        fi
                        break
                    else
                        # Use existing network
                        ZEROTIER_NETWORK_ID="${network_ids[$choice]}"
                        ZEROTIER_IP="${network_ips[$choice]}"
                        ZEROTIER_STATUS="${network_status[$choice]}"

                        echo -e "\n${GREEN}Selected Network:${NC}"
                        echo -e "  Network ID: ${CYAN}$ZEROTIER_NETWORK_ID${NC}"
                        echo -e "  IP Address: ${CYAN}$ZEROTIER_IP${NC}"
                        echo -e "  Status: ${CYAN}$ZEROTIER_STATUS${NC}"

                        if [ "$ZEROTIER_STATUS" != "OK" ]; then
                            echo -e "${YELLOW}Warning: Network status is not 'OK'. Please ensure the device is authorized in ZeroTier Central.${NC}"

                            local wait_choice
                            read -p "Do you want to wait for authorization? (Y/n): " wait_choice
                            if [[ "$wait_choice" != "n" && "$wait_choice" != "N" ]]; then
                                # Wait for proper authorization
                                join_zerotier_network "$ZEROTIER_NETWORK_ID"
                            fi
                        fi
                        break
                    fi
                else
                    echo -e "${RED}Invalid choice. Please enter a number between 1 and $manual_option.${NC}"
                fi
            done
        else
            # Fallback to manual input
            echo -e "${YELLOW}Could not parse ZeroTier network information.${NC}"
            echo -e "${CYAN}Please provide a ZeroTier Network ID to join:${NC}\n"
            prompt_input "Enter ZeroTier Network ID to join" "" "network_id_to_join"
            while [ -z "$network_id_to_join" ]; do
                echo -e "${RED}ZeroTier Network ID is required!${NC}"
                prompt_input "Enter ZeroTier Network ID to join" "" "network_id_to_join"
            done

            # Join the network and wait for IP
            if join_zerotier_network "$network_id_to_join"; then
                ZEROTIER_NETWORK_ID="$network_id_to_join"
                # ZEROTIER_IP is set in join_zerotier_network function
            else
                ZEROTIER_NETWORK_ID="$network_id_to_join"
                ZEROTIER_IP="auto-detect"
            fi
        fi
    else
        # No existing ZeroTier networks, ask for network ID to join
        echo -e "${CYAN}No existing ZeroTier networks found.${NC}"
        echo -e "${CYAN}Please provide a ZeroTier Network ID to join:${NC}\n"
        prompt_input "Enter ZeroTier Network ID to join" "" "network_id_to_join"
        while [ -z "$network_id_to_join" ]; do
            echo -e "${RED}ZeroTier Network ID is required!${NC}"
            prompt_input "Enter ZeroTier Network ID to join" "" "network_id_to_join"
        done

        # Join the network and wait for IP
        if join_zerotier_network "$network_id_to_join"; then
            ZEROTIER_NETWORK_ID="$network_id_to_join"
            # ZEROTIER_IP is set in join_zerotier_network function
        else
            ZEROTIER_NETWORK_ID="$network_id_to_join"
            ZEROTIER_IP="auto-detect"
        fi
    fi

    echo -e "\n${MAGENTA}${BOLD}System Configuration${NC}"

    # Data directory - use default automatically
    echo -e "${CYAN}Data directory: ${GREEN}$DATA_DIR${NC} ${YELLOW}(using recommended default)${NC}"

    # Timezone - use default automatically
    TZ="Asia/Jakarta"
    echo -e "${CYAN}Timezone: ${GREEN}$TZ${NC} ${YELLOW}(using recommended default)${NC}"

    # GenieACS Interface bindings - use recommended defaults automatically
    GENIEACS_CWMP_INTERFACE="0.0.0.0"
    GENIEACS_NBI_INTERFACE="0.0.0.0"
    GENIEACS_FS_INTERFACE="0.0.0.0"
    GENIEACS_UI_INTERFACE="0.0.0.0"

    echo -e "\n${CYAN}GenieACS Interface Configuration:${NC}"
    echo -e "${CYAN}  CWMP Interface (TR-069): ${GREEN}$GENIEACS_CWMP_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
    echo -e "${CYAN}  NBI Interface: ${GREEN}$GENIEACS_NBI_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
    echo -e "${CYAN}  File Server Interface: ${GREEN}$GENIEACS_FS_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
    echo -e "${CYAN}  Web UI Interface: ${GREEN}$GENIEACS_UI_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
}

# Create configuration files
create_config() {
    # Create .env file
    cat > "$INSTALL_DIR/.env" << EOF
# ZeroTier Configuration
ZEROTIER_NETWORK_ID=$ZEROTIER_NETWORK_ID

# Data directory
DATA_DIR=$DATA_DIR

# GenieACS Interface Configuration
GENIEACS_CWMP_INTERFACE=$GENIEACS_CWMP_INTERFACE
GENIEACS_NBI_INTERFACE=$GENIEACS_NBI_INTERFACE
GENIEACS_FS_INTERFACE=$GENIEACS_FS_INTERFACE
GENIEACS_UI_INTERFACE=$GENIEACS_UI_INTERFACE

# MongoDB Configuration
MONGO_DATA_DIR=/data/db

# Extensions directory on host
GENIEACS_EXT_HOST_DIR=$DATA_DIR/ext

# Timezone
TZ=$TZ
EOF

    echo -e "${GREEN}Configuration file created: $INSTALL_DIR/.env${NC}"
}

# Copy Docker files
copy_docker_files() {
    local source_dir=$(dirname "$(readlink -f "$0")")

    # Copy all necessary files
    for file in Dockerfile docker-compose.yml entrypoint.sh supervisord.conf; do
        if [ -f "$source_dir/$file" ]; then
            run_command "cp $source_dir/$file $INSTALL_DIR/" "Copying $file"
        else
            echo -e "${RED}Error: $file not found in $source_dir${NC}"
            exit 1
        fi
    done

    # Copy config directory
    if [ -d "$source_dir/config" ]; then
        run_command "cp -r $source_dir/config $INSTALL_DIR/" "Copying config directory"
    else
        echo -e "${RED}Error: config directory not found in $source_dir${NC}"
        exit 1
    fi

    run_command "chmod +x $INSTALL_DIR/entrypoint.sh" "Setting executable permissions"
}

# Fix Docker registry authentication issues with comprehensive fallbacks
fix_docker_registry() {
    echo -e "\n${MAGENTA}${BOLD}Resolving Docker Registry Issues...${NC}"

    # Step 1: Restart Docker daemon to clear cache
    echo -e "${CYAN}Restarting Docker service to clear cache...${NC}"
    run_command "systemctl restart docker" "Restarting Docker service"
    sleep 5

    # Step 2: Clear any existing authentication
    echo -e "${CYAN}Clearing Docker authentication...${NC}"
    docker logout > /dev/null 2>&1 || true

    # Step 3: Configure Docker daemon for better registry handling
    echo -e "${CYAN}Optimizing Docker daemon configuration...${NC}"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
    "registry-mirrors": [
        "https://mirror.gcr.io"
    ],
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 3,
    "max-download-attempts": 5,
    "storage-driver": "overlay2"
}
EOF

    run_command "systemctl restart docker" "Applying Docker daemon configuration"
    sleep 5

    # Step 4: Comprehensive base image pulling with multiple fallbacks
    echo -e "${CYAN}Pulling Ubuntu 22.04 base image with fallback registries...${NC}"

    # List of registries to try in order
    local registries=(
        "ubuntu:22.04"                                    # Docker Hub (primary)
        "public.ecr.aws/ubuntu/ubuntu:22.04"             # AWS ECR Public
        "mcr.microsoft.com/mirror/docker/library/ubuntu:22.04"  # Microsoft Container Registry
        "quay.io/ubuntu/ubuntu:22.04"                    # Red Hat Quay
    )

    local registry_names=(
        "Docker Hub"
        "AWS ECR Public"
        "Microsoft Container Registry"
        "Red Hat Quay"
    )

    local success=false
    local primary_failed=false

    for i in "${!registries[@]}"; do
        local registry="${registries[$i]}"
        local name="${registry_names[$i]}"

        echo -e "${YELLOW}Trying $name: $registry${NC}"

        # Try pulling with timeout
        if timeout 180 docker pull "$registry" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Successfully pulled from $name${NC}"

            # If not the primary registry, tag it as ubuntu:22.04
            if [ "$registry" != "ubuntu:22.04" ]; then
                docker tag "$registry" ubuntu:22.04
                echo -e "${GREEN}Tagged as ubuntu:22.04 for build compatibility${NC}"
            fi

            success=true
            break
        else
            echo -e "${RED}❌ Failed to pull from $name${NC}"
            if [ $i -eq 0 ]; then
                primary_failed=true
            fi
        fi

        # Small delay between attempts
        sleep 2
    done

    if [ "$success" = false ]; then
        echo -e "${RED}${BOLD}ERROR: Failed to pull Ubuntu 22.04 from all registries${NC}"
        echo -e "${YELLOW}This could be due to:${NC}"
        echo -e "  1. Internet connectivity issues"
        echo -e "  2. Docker registry rate limiting"
        echo -e "  3. Temporary registry outages"
        echo -e "${YELLOW}Please try running the installer again in a few minutes.${NC}"
        return 1
    fi

    # Step 5: Verify image is available
    echo -e "${CYAN}Verifying base image availability...${NC}"
    if docker image inspect ubuntu:22.04 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ubuntu 22.04 base image ready for build${NC}"

        if [ "$primary_failed" = true ]; then
            echo -e "${YELLOW}Note: Using alternative registry due to Docker Hub issues${NC}"
        fi

        return 0
    else
        echo -e "${RED}❌ Base image verification failed${NC}"
        return 1
    fi
}

# Build and start containers
build_and_start() {
    cd "$INSTALL_DIR"

    # Fix Docker registry issues first
    if ! fix_docker_registry; then
        echo -e "${RED}Failed to resolve Docker registry issues${NC}"
        exit 1
    fi

    run_command "docker-compose build --no-cache" "Building Docker image"
    run_command "docker-compose up -d" "Starting GenieACS container"

    echo -e "\n${CYAN}Waiting for services to be ready...${NC}"
    sleep 10

    # Show ZeroTier status from host (not from container)
    echo -e "\n${MAGENTA}${BOLD}ZeroTier Status (from host):${NC}"
    if command -v zerotier-cli > /dev/null 2>&1; then
        if zerotier-cli listnetworks > /dev/null 2>&1; then
            echo -e "${GREEN}ZeroTier service is running on host${NC}"
            zerotier-cli listnetworks | grep -v "200 listnetworks <nwid>" | while IFS= read -r line; do
                if [[ $line =~ ^200[[:space:]]listnetworks[[:space:]]([a-f0-9]+)[[:space:]]+.*[[:space:]]+([0-9\.]+/[0-9]+) ]]; then
                    local net_id="${BASH_REMATCH[1]}"
                    local ip_cidr="${BASH_REMATCH[2]}"
                    local ip_only="${ip_cidr%/*}"
                    echo -e "${CYAN}  Network: $net_id - IP: ${GREEN}$ip_only${NC}"
                fi
            done
        else
            echo -e "${YELLOW}ZeroTier service is installed but may need authorization${NC}"
        fi
    else
        echo -e "${YELLOW}ZeroTier not found on host system${NC}"
    fi
}

# Create management script
create_management_script() {
    cat > "$INSTALL_DIR/manage.sh" << 'EOF'
#!/bin/bash

INSTALL_DIR="/opt/genieacs-docker"
cd "$INSTALL_DIR"

case "$1" in
    start)
        echo "Starting GenieACS..."
        docker-compose up -d
        ;;
    stop)
        echo "Stopping GenieACS..."
        docker-compose down
        ;;
    restart)
        echo "Restarting GenieACS..."
        docker-compose restart
        ;;
    status)
        echo "GenieACS Status:"
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f --tail=100
        ;;
    zerotier-status)
        echo "ZeroTier Networks (from host):"
        if command -v zerotier-cli > /dev/null 2>&1; then
            zerotier-cli listnetworks
        else
            echo "ZeroTier not found on host system"
            echo "Note: ZeroTier runs on host, not inside container"
        fi
        ;;
    zerotier-join)
        if [ -z "$2" ]; then
            echo "Usage: $0 zerotier-join <network_id>"
            exit 1
        fi
        echo "Joining ZeroTier network on host: $2"
        if command -v zerotier-cli > /dev/null 2>&1; then
            zerotier-cli join "$2"
            echo "Note: Please authorize the device in ZeroTier Central dashboard"
        else
            echo "ZeroTier not found on host system"
        fi
        ;;
    shell)
        docker-compose exec genieacs bash
        ;;
    update)
        echo "Updating GenieACS..."
        docker-compose pull
        docker-compose up -d
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|zerotier-status|zerotier-join|shell|update}"
        echo ""
        echo "Commands:"
        echo "  start           - Start GenieACS services"
        echo "  stop            - Stop GenieACS services"
        echo "  restart         - Restart GenieACS services"
        echo "  status          - Show container status"
        echo "  logs            - Show logs (follow mode)"
        echo "  zerotier-status - Show ZeroTier network status"
        echo "  zerotier-join   - Join ZeroTier network"
        echo "  shell           - Access container shell"
        echo "  update          - Update and restart containers"
        exit 1
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/manage.sh"
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/genieacs
    echo -e "${GREEN}Management script created: $INSTALL_DIR/manage.sh${NC}"
    echo -e "${GREEN}Symlink created: /usr/local/bin/genieacs${NC}"
}

# Show final information
show_final_info() {
    echo -e "\n${GREEN}${BOLD}Installation completed successfully!${NC}\n"

    echo -e "${CYAN}Service Information:${NC}"
    echo -e "  Installation Directory: $INSTALL_DIR"
    echo -e "  Data Directory: $DATA_DIR"
    echo -e "  Configuration: $INSTALL_DIR/.env"

    echo -e "\n${CYAN}Access URLs:${NC}"
    if [ "$ZEROTIER_IP" != "auto-detect" ] && [ -n "$ZEROTIER_IP" ]; then
        echo -e "  Web UI: http://$ZEROTIER_IP:3000"
        echo -e "  CWMP (TR-069): http://$ZEROTIER_IP:7547"
        echo -e "  NBI API: http://$ZEROTIER_IP:7557"
        echo -e "  File Server: http://$ZEROTIER_IP:7567"
    else
        echo -e "  Web UI: http://<zerotier-ip>:3000"
        echo -e "  CWMP (TR-069): http://<zerotier-ip>:7547"
        echo -e "  NBI API: http://<zerotier-ip>:7557"
        echo -e "  File Server: http://<zerotier-ip>:7567"
        echo -e "\n${YELLOW}Note: Replace <zerotier-ip> with your actual ZeroTier IP address${NC}"
        echo -e "${YELLOW}Use 'genieacs zerotier-status' to check your ZeroTier IP${NC}"
    fi

    echo -e "\n${CYAN}Management Commands:${NC}"
    echo -e "  genieacs start          - Start services"
    echo -e "  genieacs stop           - Stop services"
    echo -e "  genieacs restart        - Restart services"
    echo -e "  genieacs status         - Show status"
    echo -e "  genieacs logs           - Show logs"
    echo -e "  genieacs zerotier-status - Show ZeroTier status"

    echo -e "\n${YELLOW}Important Notes:${NC}"
    if [ "$ZEROTIER_IP" != "auto-detect" ] && [ -n "$ZEROTIER_IP" ]; then
        echo -e "  1. Device is authorized and connected to ZeroTier network"
        echo -e "  2. Configure your MikroTik firewall rules if needed"
        echo -e "  3. Configure ONUs to use: http://$ZEROTIER_IP:7547"
        echo -e "  4. Check logs with: genieacs logs"
    else
        echo -e "  1. ${RED}IMPORTANT:${NC} Authorize this device in your ZeroTier Central dashboard"
        echo -e "  2. Wait for IP assignment before configuring ONUs"
        echo -e "  3. Configure your MikroTik firewall rules if needed"
        echo -e "  4. Configure ONUs to use: http://<zerotier-ip>:7547 (after getting IP)"
        echo -e "  5. Check logs with: genieacs logs"
        echo -e "  6. Use 'genieacs zerotier-status' to monitor ZeroTier connection"
    fi

    echo -e "\n${MAGENTA}ZeroTier Network Configuration:${NC}"
    echo -e "  Network ID: ${CYAN}$ZEROTIER_NETWORK_ID${NC}"
    if [ "$ZEROTIER_IP" != "auto-detect" ] && [ -n "$ZEROTIER_IP" ]; then
        echo -e "  Assigned IP: ${GREEN}$ZEROTIER_IP${NC}"
        echo -e "  Status: ${GREEN}Connected${NC}"
    else
        echo -e "  Assigned IP: ${YELLOW}Waiting for authorization...${NC}"
        echo -e "  Status: ${YELLOW}Pending authorization${NC}"
    fi
}

# Initialize log file with proper permissions
init_log() {
    # Create log file with proper permissions
    if ! touch "$LOG_FILE" 2>/dev/null; then
        # Fallback to user's home directory if /var/log is not writable
        LOG_FILE="$HOME/genieacs-docker-install.log"
        touch "$LOG_FILE" 2>/dev/null || {
            # Final fallback to current directory
            LOG_FILE="./genieacs-docker-install.log"
            touch "$LOG_FILE"
        }
    fi

    # Initialize log
    echo "GenieACS Docker Installation Log - $(date)" > "$LOG_FILE"
    chmod 644 "$LOG_FILE" 2>/dev/null
}

# Main installation process
main() {
    init_log

    print_banner
    check_root
    detect_os

    echo -e "\n${MAGENTA}${BOLD}Starting GenieACS Docker Installation${NC}\n"

    install_docker
    setup_directories
    # ZeroTier installation and network configuration are now handled in configure_network
    configure_network
    create_config
    copy_docker_files
    build_and_start
    create_management_script
    show_final_info

    echo -e "\n${GREEN}${BOLD}Installation log saved to: $LOG_FILE${NC}"
}

# Run main function
main "$@"
