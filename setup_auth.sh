#!/bin/bash
# Script pour générer/mettre à jour le mot de passe d'authentification

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HTPASSWD_FILE="$SCRIPT_DIR/.htpasswd"

echo "=========================================="
echo "  Configuration de l'authentification"
echo "=========================================="
echo ""

read -p "Nom d'utilisateur [admin]: " USERNAME
USERNAME=${USERNAME:-admin}

# Générer un mot de passe aléatoire ou demander
read -p "Mot de passe (laisser vide pour générer): " PASSWORD
if [ -z "$PASSWORD" ]; then
    PASSWORD=$(openssl rand -base64 12)
    echo "Mot de passe généré: $PASSWORD"
fi

# Créer le fichier htpasswd (format Apache)
# Utiliser openssl pour le hash
HASH=$(openssl passwd -apr1 "$PASSWORD")
echo "$USERNAME:$HASH" > "$HTPASSWD_FILE"

echo ""
echo "✅ Authentification configurée!"
echo "   Utilisateur: $USERNAME"
echo "   Mot de passe: $PASSWORD"
echo ""
echo "Fichier créé: $HTPASSWD_FILE"
echo ""
echo "⚠️  IMPORTANT: Notez ces identifiants, ils ne seront plus affichés!"
echo ""
echo "Pour redémarrer avec l'authentification activée:"
echo "  sh install.sh"
