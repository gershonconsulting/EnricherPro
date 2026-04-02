#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# EnricherPro — Hostinger VPS Setup Script
# Run once on a fresh Ubuntu 22.04 VPS as root.
# Usage: bash hostinger_vps_setup.sh YOUR_DOMAIN.com your@email.com
# ─────────────────────────────────────────────────────────────────────────────
set -e

DOMAIN="${1:?Usage: $0 <domain> <email>}"
EMAIL="${2:?Usage: $0 <domain> <email>}"
APP_DIR="/opt/enricherpro"
REPO="https://github.com/gershonconsulting/EnricherPro.git"

echo "========================================================"
echo " EnricherPro VPS Setup for $DOMAIN"
echo "========================================================"

# 1. System updates
apt-get update -y && apt-get upgrade -y
apt-get install -y git curl ufw certbot python3-certbot-nginx docker.io docker-compose-plugin

# 2. Enable firewall
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 3. Start Docker
systemctl enable docker
systemctl start docker

# 4. Clone / pull repo
if [ -d "$APP_DIR/.git" ]; then
    echo "Pulling latest code..."
    git -C "$APP_DIR" pull
else
    echo "Cloning repo..."
    git clone "$REPO" "$APP_DIR"
fi
cd "$APP_DIR"

# 5. Generate JWT secret if not present
if [ ! -f .env ]; then
    JWT=$(openssl rand -hex 32)
    echo "JWT_SECRET=$JWT" > .env
    echo "Created .env with JWT_SECRET"
fi

# 6. Update nginx domain
sed -i "s/YOUR_DOMAIN.com/$DOMAIN/g" deploy/nginx/nginx.conf

# 7. Obtain SSL certificate (Let's Encrypt — free)
mkdir -p deploy/nginx/ssl
certbot certonly --standalone --non-interactive --agree-tos \
    -m "$EMAIL" -d "$DOMAIN" -d "www.$DOMAIN"
cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem deploy/nginx/ssl/fullchain.pem
cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem   deploy/nginx/ssl/privkey.pem

# 8. Build and start containers
docker compose --env-file .env up -d --build

# 9. Auto-renew SSL via cron
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $APP_DIR/deploy/nginx/ssl/fullchain.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $APP_DIR/deploy/nginx/ssl/privkey.pem && docker compose -f $APP_DIR/docker-compose.yml restart nginx") | crontab -

echo ""
echo "========================================================"
echo " Done! EnricherPro is running at https://$DOMAIN"
echo "========================================================"
echo ""
echo "DNS RECORDS TO SET IN YOUR REGISTRAR:"
echo "  A     @       $(curl -s ifconfig.me)   (your VPS IP)"
echo "  A     www     $(curl -s ifconfig.me)"
echo "========================================================"
