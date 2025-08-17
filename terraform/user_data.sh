#!/bin/bash
# Comprehensive cloud-init script for CourierX mail server setup
# This script combines all mail server configuration into a single automated setup
set -euo pipefail

# Environment variables - these will be templated by Terraform
export DOMAIN="${domain_name}"
export NOREPLY_PASS="${noreply_pass}"
export SUPPORT_PASS="${support_pass}"
export FORWARD_TO="${forward_to}"
export SELECTOR="mail"

# Logging setup
exec > >(tee /var/log/courierx-setup.log)
exec 2>&1

echo "================================================================"
echo "CourierX Mail Server Setup Starting - $(date)"
echo "Domain: $DOMAIN"
echo "================================================================"

# 1. SYSTEM SETUP AND PACKAGE INSTALLATION
# ==========================================
echo "🔧 Updating system and installing packages..."
apt-get update -y
apt-get upgrade -y

# Install all required packages
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    postfix \
    dovecot-core \
    dovecot-imapd \
    dovecot-lmtpd \
    opendkim \
    opendkim-tools \
    mailutils \
    fail2ban \
    ufw \
    certbot \
    libsasl2-modules

echo "✅ Package installation completed"

# 2. FIREWALL CONFIGURATION
# ==========================
echo "🔒 Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 25/tcp    # SMTP
ufw allow 587/tcp   # SMTPS
ufw allow 993/tcp   # IMAPS
echo "✅ Firewall configured"

# 3. FAIL2BAN CONFIGURATION
# ==========================
echo "🛡️ Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban
echo "✅ Fail2ban configured"

# 4. HOSTNAME AND MAILNAME SETUP
# ===============================
echo "🏷️ Setting up hostname and mailname..."
hostnamectl set-hostname "mail.$DOMAIN"
echo "mail.$DOMAIN" > /etc/mailname
echo "✅ Hostname configured"

# 5. USER CREATION
# ================
echo "👥 Creating mail users..."
# Create system users for mail accounts (no shell login)
useradd -m -s /usr/sbin/nologin noreply || true
useradd -m -s /usr/sbin/nologin support || true

# Set passwords for SMTP authentication
echo "noreply:$NOREPLY_PASS" | chpasswd
echo "support:$SUPPORT_PASS" | chpasswd

echo "✅ Mail users created"

# 6. POSTFIX CONFIGURATION
# =========================
echo "📮 Configuring Postfix..."

# Basic Postfix configuration
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydestination = localhost"
postconf -e "myorigin = /etc/mailname"
postconf -e "relay_domains ="
postconf -e "smtpd_banner = \$myhostname ESMTP"

# Virtual alias configuration for forwarding
postconf -e "virtual_alias_domains = $DOMAIN"
postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"

# TLS configuration (will be updated after SSL certificates)
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_auth_only = yes"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtp_tls_security_level = may"

# SASL authentication
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"

# Basic restrictions
postconf -e "smtpd_helo_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_invalid_helo_hostname,reject_non_fqdn_helo_hostname"
postconf -e "smtpd_sender_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_non_fqdn_sender,reject_unknown_sender_domain"
postconf -e "smtpd_recipient_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_non_fqdn_recipient,reject_unknown_recipient_domain,reject_unauth_destination"

echo "✅ Postfix basic configuration completed"

# 7. EMAIL FORWARDING SETUP
# ==========================
echo "↪️ Setting up email forwarding..."
echo "support@$DOMAIN $FORWARD_TO" > /etc/postfix/virtual
postmap /etc/postfix/virtual
echo "✅ Email forwarding configured"

# 8. DOVECOT CONFIGURATION
# =========================
echo "📬 Configuring Dovecot..."

# Basic Dovecot settings
sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sed -i 's/#auth_mechanisms = plain/auth_mechanisms = plain login/' /etc/dovecot/conf.d/10-auth.conf

# Enable Dovecot SASL for Postfix
cat >> /etc/dovecot/conf.d/10-master.conf << 'EOF'

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

echo "✅ Dovecot configured"

# 9. OPENDKIM SETUP
# =================
echo "🔐 Setting up DKIM..."

# Create DKIM directories
DKIM_DIR="/etc/opendkim"
KEYS_DIR="$DKIM_DIR/keys/$DOMAIN"
mkdir -p "$KEYS_DIR"
chown -R opendkim:opendkim "$DKIM_DIR"
chmod go-rwx "$KEYS_DIR"

# Generate DKIM keys
opendkim-genkey -D "$KEYS_DIR" -d "$DOMAIN" -s "$SELECTOR"
chown opendkim:opendkim "$KEYS_DIR/$SELECTOR.private"
chmod 600 "$KEYS_DIR/$SELECTOR.private"

# Configure OpenDKIM
cat > /etc/opendkim.conf << EOF
Syslog                  yes
UMask                   002
Canonicalization        relaxed/simple
Mode                    sv
SubDomains              no
AutoRestart             yes
AutoRestartRate         10/1h
Background              yes
DNSTimeout              5
SignatureAlgorithm      rsa-sha256

KeyTable                refile:$DKIM_DIR/KeyTable
SigningTable            refile:$DKIM_DIR/SigningTable
ExternalIgnoreList      refile:$DKIM_DIR/TrustedHosts
InternalHosts           refile:$DKIM_DIR/TrustedHosts
EOF

# Create DKIM configuration files
echo "$SELECTOR._domainkey.$DOMAIN $DOMAIN:$SELECTOR:$KEYS_DIR/$SELECTOR.private" > "$DKIM_DIR/KeyTable"
echo "*@$DOMAIN $SELECTOR._domainkey.$DOMAIN" > "$DKIM_DIR/SigningTable"
cat > "$DKIM_DIR/TrustedHosts" << EOF
127.0.0.1
localhost
$DOMAIN
mail.$DOMAIN
EOF

# Fix permissions
chown -R opendkim:opendkim "$DKIM_DIR"

# Integrate OpenDKIM with Postfix
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 2"
postconf -e "smtpd_milters = inet:localhost:8891"
postconf -e "non_smtpd_milters = inet:localhost:8891"

# Store DKIM public key for easy retrieval
cp "$KEYS_DIR/$SELECTOR.txt" /etc/opendkim_public_key.txt
chmod 644 /etc/opendkim_public_key.txt

echo "✅ DKIM setup completed"

# 10. SSL CERTIFICATE SETUP (SELF-SIGNED FOR NOW)
# =================================================
echo "🔒 Setting up SSL certificates..."

# Create self-signed certificates for initial setup
SSL_DIR="/etc/ssl/courierx"
mkdir -p "$SSL_DIR"

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=mail.$DOMAIN" \
    -keyout "$SSL_DIR/mail.$DOMAIN.key" \
    -out "$SSL_DIR/mail.$DOMAIN.crt"

chmod 600 "$SSL_DIR/mail.$DOMAIN.key"
chmod 644 "$SSL_DIR/mail.$DOMAIN.crt"

# Update Postfix TLS configuration
postconf -e "smtpd_tls_cert_file = $SSL_DIR/mail.$DOMAIN.crt"
postconf -e "smtpd_tls_key_file = $SSL_DIR/mail.$DOMAIN.key"

echo "✅ SSL certificates configured (self-signed)"

# 11. SERVICE STARTUP
# ====================
echo "🚀 Starting and enabling services..."

# Enable and start services
systemctl enable opendkim
systemctl enable postfix
systemctl enable dovecot

systemctl restart opendkim
systemctl restart postfix
systemctl restart dovecot

echo "✅ All services started"

# 12. SETUP VALIDATION
# =====================
echo "🔍 Validating setup..."

# Check service status
echo "Service status:"
systemctl is-active opendkim postfix dovecot

# Test basic connectivity
ss -tulpn | grep -E ':(25|587|993|8891)\s'

echo "✅ Setup validation completed"

# 13. GENERATE SETUP SUMMARY
# ===========================
cat > /root/courierx-setup-summary.txt << EOF
================================================================
CourierX Mail Server Setup Summary
================================================================
Date: $(date)
Domain: $DOMAIN
Hostname: mail.$DOMAIN

DKIM Public Key (for DNS):
$(cat /etc/opendkim_public_key.txt)

Services Status:
- Postfix: $(systemctl is-active postfix)
- Dovecot: $(systemctl is-active dovecot)
- OpenDKIM: $(systemctl is-active opendkim)
- Fail2ban: $(systemctl is-active fail2ban)

Mail Users Created:
- noreply@$DOMAIN
- support@$DOMAIN (forwards to $FORWARD_TO)

Ports Open:
- 22 (SSH)
- 25 (SMTP)
- 587 (SMTPS)
- 993 (IMAPS)

Log Files:
- Setup log: /var/log/courierx-setup.log
- Postfix: /var/log/mail.log
- Dovecot: /var/log/dovecot.log

Next Steps:
1. Configure DNS records as shown in Terraform outputs
2. Consider replacing self-signed certificates with Let's Encrypt
3. Test email sending and receiving

================================================================
EOF

echo "================================================================"
echo "CourierX Mail Server Setup Completed Successfully! - $(date)"
echo "================================================================"
echo "Summary saved to: /root/courierx-setup-summary.txt"
echo "DKIM public key saved to: /etc/opendkim_public_key.txt"
echo "Setup log saved to: /var/log/courierx-setup.log"
echo "================================================================"
