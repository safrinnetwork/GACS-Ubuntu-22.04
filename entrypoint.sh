#!/bin/bash

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to wait for service
wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local timeout=60
    local counter=0

    log "Waiting for $service_name to be ready..."
    while [ $counter -lt $timeout ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log "$service_name is ready!"
            return 0
        fi
        sleep 1
        counter=$((counter + 1))
    done

    log "Timeout waiting for $service_name"
    return 1
}

# Detect ZeroTier IP from host network (container uses host network)
if [ -n "$ZEROTIER_NETWORK_ID" ]; then
    log "Detecting ZeroTier network configuration..."

    # Find ZeroTier interface on host
    for interface in $(ip link show | grep -E "^[0-9]+: zt" | cut -d: -f2 | tr -d ' '); do
        zt_ip=$(ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
        if [ -n "$zt_ip" ]; then
            log "Found ZeroTier interface $interface with IP: $zt_ip"
            echo "" >> /opt/genieacs/genieacs.env
            echo "ZEROTIER_IP=$zt_ip" >> /opt/genieacs/genieacs.env
            break
        fi
    done

    if [ -z "$zt_ip" ]; then
        log "Warning: No ZeroTier interface found. Using host networking."
    fi
fi

# Generate JWT secret if not exists
if [ ! -f /opt/genieacs/genieacs.env ] || ! grep -q "GENIEACS_UI_JWT_SECRET" /opt/genieacs/genieacs.env; then
    log "Generating JWT secret..."
    jwt_secret=$(node -e "console.log(require('crypto').randomBytes(128).toString('hex'))")
    echo "GENIEACS_UI_JWT_SECRET=$jwt_secret" >> /opt/genieacs/genieacs.env
fi

# Set MongoDB data directory
export MONGO_DATA_DIR=${MONGO_DATA_DIR:-/data/db}

# Start MongoDB
log "Starting MongoDB..."
mongod --fork --logpath /var/log/mongodb/mongod.log --dbpath $MONGO_DATA_DIR --bind_ip_all

# Wait for MongoDB to be ready
wait_for_service "MongoDB" "mongo --eval 'db.runCommand({ping: 1})'"

# Set environment variables
export $(grep -v '^#' /opt/genieacs/genieacs.env | xargs)

# Configure GenieACS based on environment variables
if [ -n "$GENIEACS_CWMP_INTERFACE" ]; then
    export GENIEACS_CWMP_INTERFACE
fi

if [ -n "$GENIEACS_NBI_INTERFACE" ]; then
    export GENIEACS_NBI_INTERFACE
fi

if [ -n "$GENIEACS_FS_INTERFACE" ]; then
    export GENIEACS_FS_INTERFACE
fi

if [ -n "$GENIEACS_UI_INTERFACE" ]; then
    export GENIEACS_UI_INTERFACE
fi

# Start supervisor to manage GenieACS services
log "Starting GenieACS services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf