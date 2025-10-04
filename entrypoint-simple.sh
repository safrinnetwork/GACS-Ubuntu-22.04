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

# Set environment variables - export each line properly
while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Export the variable
    export "$line"
done < /opt/genieacs/genieacs.env

# Start supervisor to manage GenieACS services
log "Starting GenieACS services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
