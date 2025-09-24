#!/bin/bash

# GenieACS Docker Universal Installer
# Compatible with any VPS and ZeroTier network configuration
# Author: AI Assistant
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
LOG_FILE="/tmp/genieacs-docker-install.log"

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
    eval "$cmd" >> "$LOG_FILE" 2>&1 &
    spinner $!
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
        echo -e "${RED}Check log file: $LOG_FILE${NC}"
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

# Check for root access
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
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

# Detect existing ZeroTier networks
detect_zerotier_networks() {
    echo -e "\n${CYAN}Detecting existing ZeroTier networks...${NC}"

    # Check if ZeroTier is installed
    if ! command -v zerotier-cli > /dev/null 2>&1; then
        echo -e "${YELLOW}ZeroTier not found. Will need to configure network ID manually.${NC}"
        return 1
    fi

    # Get existing networks
    local networks_output
    networks_output=$(zerotier-cli listnetworks 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$networks_output" ]; then
        echo -e "${YELLOW}No ZeroTier networks found or ZeroTier service not running.${NC}"
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
    echo -e "${CYAN}$((counter-1)). Enter new Network ID manually${NC}"

    return $((counter-1))
}

# Get network configuration
configure_network() {
    echo -e "\n${MAGENTA}${BOLD}Network Configuration${NC}"

    # Try to detect existing ZeroTier networks
    local networks_info
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
                        # Manual entry
                        echo -e "\n${CYAN}Manual Network Configuration:${NC}"
                        prompt_input "Enter ZeroTier Network ID" "" "ZEROTIER_NETWORK_ID"
                        while [ -z "$ZEROTIER_NETWORK_ID" ]; do
                            echo -e "${RED}ZeroTier Network ID is required!${NC}"
                            prompt_input "Enter ZeroTier Network ID" "" "ZEROTIER_NETWORK_ID"
                        done
                        ZEROTIER_IP="auto-detect"
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
                        fi
                        break
                    fi
                else
                    echo -e "${RED}Invalid choice. Please enter a number between 1 and $manual_option.${NC}"
                fi
            done
        else
            # Fallback to manual input
            echo -e "${YELLOW}Could not parse ZeroTier network information. Using manual configuration.${NC}"
            prompt_input "Enter ZeroTier Network ID" "" "ZEROTIER_NETWORK_ID"
            while [ -z "$ZEROTIER_NETWORK_ID" ]; do
                echo -e "${RED}ZeroTier Network ID is required!${NC}"
                prompt_input "Enter ZeroTier Network ID" "" "ZEROTIER_NETWORK_ID"
            done
            ZEROTIER_IP="auto-detect"
        fi
    else
        # No ZeroTier detected, manual input
        echo -e "${CYAN}Please provide your network configuration:${NC}\n"
        prompt_input "Enter ZeroTier Network ID" "" "ZEROTIER_NETWORK_ID"
        while [ -z "$ZEROTIER_NETWORK_ID" ]; do
            echo -e "${RED}ZeroTier Network ID is required!${NC}"
            prompt_input "Enter ZeroTier Network ID" "" "ZEROTIER_NETWORK_ID"
        done
        ZEROTIER_IP="auto-detect"
    fi

    # Data directory
    prompt_input "Data directory path" "$DATA_DIR" "DATA_DIR_INPUT"
    DATA_DIR="$DATA_DIR_INPUT"

    # Timezone
    prompt_input "Timezone" "Asia/Jakarta" "TZ"

    # GenieACS Interface bindings
    echo -e "\n${CYAN}GenieACS Interface Configuration (use 0.0.0.0 for all interfaces):${NC}"
    prompt_input "CWMP Interface (TR-069)" "0.0.0.0" "GENIEACS_CWMP_INTERFACE"
    prompt_input "NBI Interface" "0.0.0.0" "GENIEACS_NBI_INTERFACE"
    prompt_input "File Server Interface" "0.0.0.0" "GENIEACS_FS_INTERFACE"
    prompt_input "Web UI Interface" "0.0.0.0" "GENIEACS_UI_INTERFACE"
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

# Build and start containers
build_and_start() {
    cd "$INSTALL_DIR"

    run_command "docker-compose build" "Building Docker image"
    run_command "docker-compose up -d" "Starting GenieACS container"

    echo -e "\n${CYAN}Waiting for services to be ready...${NC}"
    sleep 10

    # Show ZeroTier status
    echo -e "\n${MAGENTA}${BOLD}ZeroTier Status:${NC}"
    docker-compose exec genieacs zerotier-cli listnetworks 2>/dev/null || echo -e "${YELLOW}ZeroTier status will be available after network authorization${NC}"
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
        echo "ZeroTier Networks:"
        docker-compose exec genieacs zerotier-cli listnetworks
        ;;
    zerotier-join)
        if [ -z "$2" ]; then
            echo "Usage: $0 zerotier-join <network_id>"
            exit 1
        fi
        docker-compose exec genieacs zerotier-cli join "$2"
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

    echo -e "\n${CYAN}Access URLs (after ZeroTier authorization):${NC}"
    echo -e "  Web UI: http://<zerotier-ip>:3000"
    echo -e "  CWMP (TR-069): http://<zerotier-ip>:7547"
    echo -e "  NBI API: http://<zerotier-ip>:7557"
    echo -e "  File Server: http://<zerotier-ip>:7567"

    echo -e "\n${CYAN}Management Commands:${NC}"
    echo -e "  genieacs start          - Start services"
    echo -e "  genieacs stop           - Stop services"
    echo -e "  genieacs restart        - Restart services"
    echo -e "  genieacs status         - Show status"
    echo -e "  genieacs logs           - Show logs"
    echo -e "  genieacs zerotier-status - Show ZeroTier status"

    echo -e "\n${YELLOW}Important Notes:${NC}"
    echo -e "  1. Authorize this device in your ZeroTier Central dashboard"
    echo -e "  2. Configure your MikroTik firewall rules if needed"
    echo -e "  3. Configure ONUs to use: http://<zerotier-ip>:7547"
    echo -e "  4. Check logs with: genieacs logs"

    echo -e "\n${MAGENTA}ZeroTier Network ID: $ZEROTIER_NETWORK_ID${NC}"
}

# Main installation process
main() {
    # Initialize log
    echo "GenieACS Docker Installation Log - $(date)" > "$LOG_FILE"

    print_banner
    check_root
    detect_os

    echo -e "\n${MAGENTA}${BOLD}Starting GenieACS Docker Installation${NC}\n"

    install_docker
    setup_directories
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