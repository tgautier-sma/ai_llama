#!/bin/sh
# Script de génération de certificats SSL auto-signés

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSL_DIR="$SCRIPT_DIR/ssl"

# Créer le dossier ssl
mkdir -p "$SSL_DIR"

# Vérifier si les certificats existent déjà
if [ -f "$SSL_DIR/server.crt" ] && [ -f "$SSL_DIR/server.key" ]; then
    echo "✅ Certificats SSL déjà présents"
    echo "   Pour régénérer: rm -rf $SSL_DIR && sh $0"
    exit 0
fi

echo "=========================================="
echo "  Génération des certificats SSL"
echo "=========================================="
echo ""

# Demander le nom de domaine/IP
read -p "Nom de domaine ou IP [localhost]: " DOMAIN
DOMAIN=${DOMAIN:-localhost}

echo ""
echo "Génération du certificat pour: $DOMAIN"
echo ""

# Générer la clé privée et le certificat auto-signé
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/server.key" \
    -out "$SSL_DIR/server.crt" \
    -subj "/C=FR/ST=France/L=Paris/O=LLaMA Server/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1" \
    2>/dev/null

# Restreindre les permissions
chmod 600 "$SSL_DIR/server.key"
chmod 644 "$SSL_DIR/server.crt"

echo "✅ Certificats SSL générés!"
echo ""
echo "   Certificat: $SSL_DIR/server.crt"
echo "   Clé privée: $SSL_DIR/server.key"
echo "   Validité:   365 jours"
echo ""
echo "⚠️  Note: Certificat auto-signé"
echo "   Le navigateur affichera un avertissement de sécurité."
echo "   Pour la production, utilisez Let's Encrypt ou un certificat valide."
echo ""
