#!/bin/bash
# 🚀 DigitalOcean Landing Page Server - One-Line Setup Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/server-scripts/main/setup.sh)"

set -e  # Exit on error

echo "🚀 DigitalOcean Landing Page Server Setup"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

print_status "Starting server setup..."

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y > /dev/null 2>&1

# Install required packages
print_status "Installing nginx, git, and security tools..."
apt install -y nginx git curl wget ufw fail2ban net-tools > /dev/null 2>&1

# Configure firewall
print_status "Configuring firewall..."
ufw allow OpenSSH > /dev/null 2>&1
ufw allow 'Nginx Full' > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1

# Create web directory
print_status "Creating web directory..."
mkdir -p /var/www/landing
chown -R www-data:www-data /var/www/landing

# Configure nginx
print_status "Configuring nginx..."
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/landing;
    index index.html index.htm;
    
    server_name _;
    
    # Handle root requests
    location = / {
        try_files /index.html =404;
    }
    
    # Handle specific landing page folders
    location ~ ^/([^/]+)/?$ {
        try_files /$1/index.html /index.html;
    }
    
    # Handle files within landing page folders
    location ~ ^/([^/]+)/(.*)$ {
        try_files /$1/$2 /index.html;
    }
    
    # Fallback for any other requests
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

# Remove old symlinks and create new one
rm -f /etc/nginx/sites-enabled/*
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Test and reload nginx
nginx -t > /dev/null 2>&1
systemctl reload nginx

# Create deployer user for GitHub Actions
print_status "Creating deployer user for automated deployments..."
if ! id "deployer" &>/dev/null; then
    adduser --disabled-password --gecos "" deployer
    echo "deployer ALL=(ALL) NOPASSWD: /usr/bin/git, /bin/chown, /usr/bin/find" >> /etc/sudoers
fi

# Generate SSH key for deployer
print_status "Generating SSH keys for GitHub Actions..."
su - deployer -c "mkdir -p ~/.ssh && ssh-keygen -t rsa -b 4096 -C 'github-actions@server' -f ~/.ssh/id_rsa -N ''"

# Create a simple landing page
print_status "Creating default landing page..."
cat > /var/www/landing/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Ready!</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 3rem; margin-bottom: 1rem; }
        p { font-size: 1.2rem; opacity: 0.9; }
        .emoji { font-size: 4rem; margin-bottom: 1rem; }
    </style>
</head>
<body>
    <div class="container">
        <div class="emoji">🚀</div>
        <h1>Server Ready!</h1>
        <p>Your landing page server is configured and ready to use.</p>
        <p>Upload your landing pages to see them here.</p>
    </div>
</body>
</html>
EOF

# Set correct permissions
chown -R www-data:www-data /var/www/landing

# Configure fail2ban for security
print_status "Configuring fail2ban for security..."
systemctl enable fail2ban
systemctl start fail2ban

# Get server IP
SERVER_IP=$(curl -s http://checkip.amazonaws.com)

echo ""
echo "========================================="
print_status "✅ Server setup complete!"
echo "========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Add Deploy Key to GitHub:"
echo "   Copy this public key to your GitHub repo's deploy keys:"
echo ""
cat /home/deployer/.ssh/id_rsa.pub
echo ""
echo "2. Get Private Key for GitHub Actions:"
echo "   Run: cat /home/deployer/.ssh/id_rsa"
echo ""
echo "3. Your server is accessible at:"
echo "   http://$SERVER_IP"
echo ""
echo "4. To setup SSL (HTTPS):"
echo "   - Point your domain to: $SERVER_IP"
echo "   - Run: certbot --nginx -d yourdomain.com"
echo ""
echo "========================================="
print_status "Happy deploying! 🎉" 
