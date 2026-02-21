#!/bin/bash
set -e

# Port par défaut ou passé en argument
PORT=${1:-8088}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/models"
mkdir -p "$MODELS_DIR"

# Vérifier l'authentification
HTPASSWD_FILE="$SCRIPT_DIR/.htpasswd"
if [ ! -f "$HTPASSWD_FILE" ]; then
    echo "=========================================="
    echo "  ⚠️  Authentification non configurée"
    echo "=========================================="
    echo ""
    read -p "Configurer l'authentification maintenant? [O/n]: " SETUP_AUTH
    SETUP_AUTH=${SETUP_AUTH:-O}
    
    if [ "$SETUP_AUTH" = "O" ] || [ "$SETUP_AUTH" = "o" ] || [ "$SETUP_AUTH" = "Y" ] || [ "$SETUP_AUTH" = "y" ]; then
        read -p "Nom d'utilisateur [admin]: " AUTH_USER
        AUTH_USER=${AUTH_USER:-admin}
        
        read -p "Mot de passe (vide = générer): " AUTH_PASS
        if [ -z "$AUTH_PASS" ]; then
            AUTH_PASS=$(openssl rand -base64 12)
            echo "Mot de passe généré: $AUTH_PASS"
        fi
        
        AUTH_HASH=$(openssl passwd -apr1 "$AUTH_PASS")
        echo "$AUTH_USER:$AUTH_HASH" > "$HTPASSWD_FILE"
        
        echo ""
        echo "✅ Authentification configurée!"
        echo "   Utilisateur: $AUTH_USER"
        echo "   Mot de passe: $AUTH_PASS"
        echo ""
        echo "⚠️  NOTEZ CES IDENTIFIANTS!"
        echo ""
    else
        # Créer des credentials par défaut (non sécurisé)
        DEFAULT_HASH=$(openssl passwd -apr1 "changeme")
        echo "admin:$DEFAULT_HASH" > "$HTPASSWD_FILE"
        echo ""
        echo "⚠️  Identifiants par défaut créés:"
        echo "   Utilisateur: admin"
        echo "   Mot de passe: changeme"
        echo ""
        echo "   CHANGEZ-LES avec: sh setup_auth.sh"
        echo ""
    fi
fi

# Vérifier les certificats SSL
SSL_DIR="$SCRIPT_DIR/ssl"
if [ ! -f "$SSL_DIR/server.crt" ] || [ ! -f "$SSL_DIR/server.key" ]; then
    echo ""
    echo "=========================================="
    echo "  Génération des certificats SSL"
    echo "=========================================="
    echo ""
    mkdir -p "$SSL_DIR"
    read -p "Nom de domaine ou IP [localhost]: " SSL_DOMAIN
    SSL_DOMAIN=${SSL_DOMAIN:-localhost}
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/server.key" \
        -out "$SSL_DIR/server.crt" \
        -subj "/C=FR/ST=France/L=Paris/O=LLaMA Server/CN=$SSL_DOMAIN" \
        -addext "subjectAltName=DNS:$SSL_DOMAIN,DNS:localhost,IP:127.0.0.1" \
        2>/dev/null
    
    chmod 600 "$SSL_DIR/server.key"
    chmod 644 "$SSL_DIR/server.crt"
    echo "✅ Certificat SSL généré pour: $SSL_DOMAIN"
    echo ""
fi

# Menu de sélection du modèle
echo "=========================================="
echo "  Sélection du modèle LLM local"
echo "=========================================="
echo ""
echo "Choisissez le modèle à installer :"
echo ""
echo "  1) Mistral   - Ministral 8B (4.9GB) - Modèle français performant"
echo "  2) Gemma     - Gemma 2 9B (5.4GB)   - Alternative Google Gemini"
echo "  3) Llama     - Llama 3.2 3B (1.9GB) - Alternative ChatGPT"
echo "  4) Qwen      - Qwen 2.5 7B (4.4GB)  - Alternative Claude"
echo "  5) LLaVA     - LLaVA 1.6 7B (4.1GB) - Vision (analyse images)"
echo ""
read -p "Votre choix [1-5]: " choice

case "$choice" in
    1)
        MODEL_NAME="Mistral"
        MODEL_URL="https://huggingface.co/bartowski/Ministral-8B-Instruct-2410-GGUF/resolve/main/Ministral-8B-Instruct-2410-Q4_K_M.gguf"
        MODEL_FILE="Ministral-8B-Instruct-2410-Q4_K_M.gguf"
        MODEL_SIZE="4.9GB"
        VISION_MODEL=""
        ;;
    2)
        MODEL_NAME="Gemma"
        MODEL_URL="https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf"
        MODEL_FILE="gemma-2-9b-it-Q4_K_M.gguf"
        MODEL_SIZE="5.4GB"
        VISION_MODEL=""
        ;;
    3)
        MODEL_NAME="Llama"
        MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        MODEL_FILE="Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        MODEL_SIZE="1.9GB"
        VISION_MODEL=""
        ;;
    4)
        MODEL_NAME="Qwen"
        MODEL_URL="https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
        MODEL_FILE="Qwen2.5-7B-Instruct-Q4_K_M.gguf"
        MODEL_SIZE="4.4GB"
        VISION_MODEL=""
        ;;
    5)
        MODEL_NAME="LLaVA"
        MODEL_URL="https://huggingface.co/cjpais/llava-1.6-mistral-7b-gguf/resolve/main/llava-v1.6-mistral-7b.Q4_K_M.gguf"
        MODEL_FILE="llava-v1.6-mistral-7b.Q4_K_M.gguf"
        MODEL_SIZE="4.1GB"
        VISION_MODEL="true"
        MMPROJ_URL="https://huggingface.co/cjpais/llava-1.6-mistral-7b-gguf/resolve/main/mmproj-model-f16.gguf"
        MMPROJ_FILE="mmproj-llava-v1.6-mistral-7b-f16.gguf"
        ;;
    *)
        echo "Choix invalide. Utilisation de Llama par défaut."
        MODEL_NAME="Llama"
        MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        MODEL_FILE="Llama-3.2-3B-Instruct-Q4_K_M.gguf"
        MODEL_SIZE="1.9GB"
        VISION_MODEL=""
        ;;
esac

MODEL_PATH="$MODELS_DIR/$MODEL_FILE"

echo ""
echo "Modèle sélectionné: $MODEL_NAME ($MODEL_FILE)"

if [ ! -f "$MODEL_PATH" ]; then
    echo "Téléchargement de $MODEL_NAME (~$MODEL_SIZE)..."
    wget --progress=bar:force -O "$MODEL_PATH" "$MODEL_URL"
else
    echo "Modèle déjà téléchargé."
fi

# Télécharger le projecteur multimodal pour les modèles vision
if [ "$VISION_MODEL" = "true" ]; then
    MMPROJ_PATH="$MODELS_DIR/$MMPROJ_FILE"
    if [ ! -f "$MMPROJ_PATH" ]; then
        echo "Téléchargement du projecteur vision..."
        wget --progress=bar:force -O "$MMPROJ_PATH" "$MMPROJ_URL"
    fi
    export LLAMA_MMPROJ=$MMPROJ_FILE
    export LLAMA_VISION=true
else
    export LLAMA_VISION=false
fi

echo "Démarrage du serveur API REST sur le port $PORT avec $MODEL_NAME..."
cd "$SCRIPT_DIR"
export LLAMA_PORT=$PORT
export PDF_PORT=$((PORT + 1))
export PROXY_PORT=5020
export PROXY_PORT_SSL=5021
export LLAMA_MODEL=$MODEL_FILE

# Sélectionner le profil selon le type de modèle
if [ "$VISION_MODEL" = "true" ]; then
    PROFILE="vision"
    echo "Mode Vision activé - analyse d'images directe"
else
    PROFILE="text"
fi

# Arrêter les conteneurs existants pour libérer le port
echo "Arrêt des conteneurs précédents..."
docker compose --profile text down 2>/dev/null || true
docker compose --profile vision down 2>/dev/null || true
docker stop llama-server llama-server-vision llama-pdf-service llama-proxy 2>/dev/null || true
docker rm llama-server llama-server-vision llama-pdf-service llama-proxy 2>/dev/null || true

docker compose --profile $PROFILE up -d --build

# Ports HTTPS
PROXY_PORT_SSL=${PROXY_PORT_SSL:-5021}

echo ""
echo "=========================================="
echo "  Serveur $MODEL_NAME démarré!"
echo "=========================================="
echo ""
echo "🔒 Interfaces Web (HTTPS):"
echo "  Chat + PDF:     https://localhost:$PROXY_PORT_SSL"
echo "  LLaMA UI:       https://localhost:$PROXY_PORT_SSL/llama-ui/"
echo "  Documentation:  https://localhost:$PROXY_PORT_SSL/docs"
echo ""
echo "📍 Via HTTP (redirige vers HTTPS):"
echo "  http://localhost:$PROXY_PORT → https://localhost:$PROXY_PORT_SSL"
echo ""
echo "🛣️  Routes:"
echo "  /           - Interface Chat + PDF"
echo "  /llama-ui/  - Interface LLaMA native"
echo "  /llm/*      - API LLM (llama.cpp)"
echo "  /pdf/*      - API PDF Service"
echo "  /docs       - Swagger UI"
echo ""
echo "Modèle: $MODEL_NAME ($MODEL_FILE)"
if [ "$VISION_MODEL" = "true" ]; then
    echo "Mode: Vision (analyse d'images)"
fi
echo ""
echo "🔐 Authentification: HTTP Basic (admin:changeme par défaut)"
echo "   Modifier: sh setup_auth.sh"
echo ""
echo "Exemples:"
echo "  curl -k -u admin:changeme https://localhost:$PROXY_PORT_SSL/llm/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}'"