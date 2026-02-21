#!/bin/sh
# Script pour gérer les utilisateurs (multi-utilisateurs)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HTPASSWD_FILE="$SCRIPT_DIR/.htpasswd"

# Créer le fichier s'il n'existe pas
touch "$HTPASSWD_FILE"

show_menu() {
    echo ""
    echo "=========================================="
    echo "  Gestion des utilisateurs"
    echo "=========================================="
    echo ""
    echo "  1) Ajouter un utilisateur"
    echo "  2) Modifier un mot de passe"
    echo "  3) Supprimer un utilisateur"
    echo "  4) Lister les utilisateurs"
    echo "  5) Quitter"
    echo ""
}

list_users() {
    echo ""
    echo "Utilisateurs enregistrés:"
    echo "-------------------------"
    if [ -s "$HTPASSWD_FILE" ]; then
        cut -d: -f1 "$HTPASSWD_FILE" | while read user; do
            echo "  - $user"
        done
    else
        echo "  (aucun utilisateur)"
    fi
    echo ""
}

add_user() {
    echo ""
    read -p "Nom d'utilisateur: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo "❌ Nom d'utilisateur requis"
        return
    fi
    
    # Vérifier si l'utilisateur existe déjà
    if grep -q "^$USERNAME:" "$HTPASSWD_FILE" 2>/dev/null; then
        echo "❌ L'utilisateur '$USERNAME' existe déjà. Utilisez 'Modifier' pour changer son mot de passe."
        return
    fi
    
    read -p "Mot de passe (vide = générer): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(openssl rand -base64 12)
        echo "Mot de passe généré: $PASSWORD"
    fi
    
    HASH=$(openssl passwd -apr1 "$PASSWORD")
    echo "$USERNAME:$HASH" >> "$HTPASSWD_FILE"
    
    echo ""
    echo "✅ Utilisateur '$USERNAME' ajouté!"
    echo "   Mot de passe: $PASSWORD"
    echo ""
    echo "⚠️  NOTEZ CE MOT DE PASSE!"
}

modify_user() {
    list_users
    read -p "Utilisateur à modifier: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo "❌ Nom d'utilisateur requis"
        return
    fi
    
    if ! grep -q "^$USERNAME:" "$HTPASSWD_FILE" 2>/dev/null; then
        echo "❌ L'utilisateur '$USERNAME' n'existe pas"
        return
    fi
    
    read -p "Nouveau mot de passe (vide = générer): " PASSWORD
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(openssl rand -base64 12)
        echo "Mot de passe généré: $PASSWORD"
    fi
    
    HASH=$(openssl passwd -apr1 "$PASSWORD")
    
    # Supprimer l'ancienne ligne et ajouter la nouvelle
    grep -v "^$USERNAME:" "$HTPASSWD_FILE" > "$HTPASSWD_FILE.tmp"
    echo "$USERNAME:$HASH" >> "$HTPASSWD_FILE.tmp"
    mv "$HTPASSWD_FILE.tmp" "$HTPASSWD_FILE"
    
    echo ""
    echo "✅ Mot de passe de '$USERNAME' modifié!"
    echo "   Nouveau mot de passe: $PASSWORD"
    echo ""
    echo "⚠️  NOTEZ CE MOT DE PASSE!"
}

delete_user() {
    list_users
    read -p "Utilisateur à supprimer: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo "❌ Nom d'utilisateur requis"
        return
    fi
    
    if ! grep -q "^$USERNAME:" "$HTPASSWD_FILE" 2>/dev/null; then
        echo "❌ L'utilisateur '$USERNAME' n'existe pas"
        return
    fi
    
    read -p "Confirmer la suppression de '$USERNAME'? [o/N]: " CONFIRM
    if [ "$CONFIRM" = "o" ] || [ "$CONFIRM" = "O" ]; then
        grep -v "^$USERNAME:" "$HTPASSWD_FILE" > "$HTPASSWD_FILE.tmp"
        mv "$HTPASSWD_FILE.tmp" "$HTPASSWD_FILE"
        echo "✅ Utilisateur '$USERNAME' supprimé"
    else
        echo "Annulé"
    fi
}

# Mode interactif ou ajout direct
if [ "$1" = "add" ] && [ -n "$2" ]; then
    # Mode ligne de commande: sh setup_auth.sh add username [password]
    USERNAME="$2"
    PASSWORD="${3:-$(openssl rand -base64 12)}"
    
    if grep -q "^$USERNAME:" "$HTPASSWD_FILE" 2>/dev/null; then
        echo "❌ L'utilisateur '$USERNAME' existe déjà"
        exit 1
    fi
    
    HASH=$(openssl passwd -apr1 "$PASSWORD")
    echo "$USERNAME:$HASH" >> "$HTPASSWD_FILE"
    echo "✅ Utilisateur '$USERNAME' ajouté (mot de passe: $PASSWORD)"
    exit 0
fi

if [ "$1" = "list" ]; then
    list_users
    exit 0
fi

if [ "$1" = "delete" ] && [ -n "$2" ]; then
    USERNAME="$2"
    if grep -q "^$USERNAME:" "$HTPASSWD_FILE" 2>/dev/null; then
        grep -v "^$USERNAME:" "$HTPASSWD_FILE" > "$HTPASSWD_FILE.tmp"
        mv "$HTPASSWD_FILE.tmp" "$HTPASSWD_FILE"
        echo "✅ Utilisateur '$USERNAME' supprimé"
    else
        echo "❌ Utilisateur '$USERNAME' non trouvé"
        exit 1
    fi
    exit 0
fi

# Mode interactif
while true; do
    show_menu
    read -p "Choix [1-5]: " choice
    
    case "$choice" in
        1) add_user ;;
        2) modify_user ;;
        3) delete_user ;;
        4) list_users ;;
        5) echo "Au revoir!"; exit 0 ;;
        *) echo "Choix invalide" ;;
    esac
done
