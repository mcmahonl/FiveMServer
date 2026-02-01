#!/bin/bash
set -e

echo "==================================="
echo "FiveM Racing Server Setup"
echo "==================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo ./setup.sh)"
  exit 1
fi

# Update system
echo "[1/5] Updating system..."
apt update && apt upgrade -y

# Install Docker
echo "[2/5] Installing Docker..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
else
  echo "Docker already installed"
fi

# Install Docker Compose
echo "[3/5] Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
  apt install -y docker-compose-plugin
fi

# Create .env file if it doesn't exist
echo "[4/5] Setting up environment..."
if [ ! -f .env ]; then
  echo "Creating .env file..."
  cat > .env << 'EOF'
# Get your license key from https://keymaster.fivem.net/
FIVEM_LICENSE_KEY=your_license_key_here

# Database passwords (change these!)
DB_ROOT_PASSWORD=changeme_root
DB_PASSWORD=changeme_fivem

# RCON password for server management
RCON_PASSWORD=changeme_rcon
EOF
  echo ""
  echo "!! IMPORTANT !!"
  echo "Edit .env file with your FiveM license key:"
  echo "  nano .env"
  echo ""
fi

# Open firewall ports
echo "[5/5] Configuring firewall..."
if command -v ufw &> /dev/null; then
  ufw allow 30120/tcp
  ufw allow 30120/udp
  ufw allow 40120/tcp
  echo "Firewall configured"
fi

echo ""
echo "==================================="
echo "Setup complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Edit .env with your FiveM license key"
echo "   nano .env"
echo ""
echo "2. Get a license key from:"
echo "   https://keymaster.fivem.net/"
echo ""
echo "3. Start the server:"
echo "   docker compose up -d"
echo ""
echo "4. Access txAdmin at:"
echo "   http://YOUR_SERVER_IP:40120"
echo ""
echo "5. View logs:"
echo "   docker compose logs -f"
echo ""
