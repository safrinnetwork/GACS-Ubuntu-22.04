FROM ubuntu:22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    systemd \
    iproute2 \
    iptables \
    net-tools \
    dbus \
    supervisor \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install libssl1.1 for MongoDB compatibility
RUN wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
    && dpkg -i libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
    && rm libssl1.1_1.1.0g-2ubuntu4_amd64.deb

# Install MongoDB 4.4 (compatible with GenieACS)
RUN wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add - \
    && echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list \
    && apt-get update \
    && apt-get install -y mongodb-org

# Note: ZeroTier akan menggunakan host networking, tidak perlu install di container

# Install GenieACS
RUN npm install -g genieacs@1.2.13

# Create genieacs user and directories
RUN useradd --system --no-create-home --user-group genieacs \
    && mkdir -p /opt/genieacs/ext \
    && mkdir -p /var/log/genieacs \
    && chown -R genieacs:genieacs /opt/genieacs \
    && chown -R genieacs:genieacs /var/log/genieacs

# Create data directories
RUN mkdir -p /data/db /data/logs \
    && chown -R mongodb:mongodb /data/db \
    && chown -R genieacs:genieacs /data/logs

# Copy configuration files
COPY config/ /opt/genieacs/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh

# Set proper permissions
RUN chown genieacs:genieacs /opt/genieacs/genieacs.env \
    && chmod 600 /opt/genieacs/genieacs.env

# Expose ports
EXPOSE 7547 7557 7567 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start services using supervisor
CMD ["/entrypoint.sh"]