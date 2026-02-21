# LLaMA Server - Serveur LLM Local

Serveur LLM local clé en main avec interface web, API REST, analyse de PDF/OCR, et support vision.

## Fonctionnalités

- **5 modèles disponibles** : Mistral, Gemma, Llama, Qwen, LLaVA (vision)
- **Interface web** : Chat interactif + analyse de PDF
- **API REST** : Compatible OpenAI (`/v1/chat/completions`)
- **Analyse PDF** : Extraction de texte avec OCR (Tesseract)
- **Mode Vision** : Analyse d'images avec LLaVA
- **Sécurité** : HTTPS/TLS, authentification HTTP Basic, rate limiting
- **Docker** : Déploiement containerisé avec profiles

## Installation rapide

```bash
sh install.sh
```

Le script interactif vous guidera pour :
1. Configurer l'authentification
2. Générer les certificats SSL
3. Choisir le modèle LLM
4. Démarrer les services

## Accès

| URL | Description |
|-----|-------------|
| `https://localhost:5021` | Interface Chat + PDF |
| `https://localhost:5021/llama-ui/` | Interface llama.cpp native |
| `https://localhost:5021/docs` | Documentation API (Swagger) |

> HTTP (`http://localhost:5020`) redirige automatiquement vers HTTPS.

## Modèles disponibles

| # | Modèle | Taille | Description |
|---|--------|--------|-------------|
| 1 | Mistral 8B | 4.9 GB | Modèle français performant |
| 2 | Gemma 2 9B | 5.4 GB | Alternative Google Gemini |
| 3 | Llama 3.2 3B | 1.9 GB | Alternative ChatGPT (léger) |
| 4 | Qwen 2.5 7B | 4.4 GB | Alternative Claude |
| 5 | LLaVA 1.6 7B | 4.1 GB | Vision (analyse d'images) |

## API REST

### Chat Completion

```bash
curl -k -u admin:changeme https://localhost:5021/llm/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "messages": [{"role": "user", "content": "Bonjour!"}],
    "temperature": 0.7
  }'
```

### Analyse de PDF

```bash
curl -k -u admin:changeme https://localhost:5021/pdf/analyze \
  -F "file=@document.pdf" \
  -F "question=Résume ce document"
```

### Analyse d'image (mode LLaVA)

```bash
curl -k -u admin:changeme https://localhost:5021/pdf/analyze-image \
  -F "file=@photo.jpg" \
  -F "question=Décris cette image"
```

### Health Check

```bash
curl -k -u admin:changeme https://localhost:5021/llm/health
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Nginx Proxy                          │
│              (HTTPS + Auth + Rate Limit)                │
│                   Port 5021 (SSL)                       │
├─────────────┬─────────────────────┬─────────────────────┤
│     /       │      /llm/*         │      /pdf/*         │
│  Interface  │     API LLM         │   Service PDF       │
├─────────────┼─────────────────────┼─────────────────────┤
│             │   llama-server      │   pdf-service       │
│  Web UI     │   (llama.cpp)       │   (FastAPI)         │
│  (static)   │   Port 8080         │   Port 8000         │
│             │                     │   + Tesseract OCR   │
└─────────────┴─────────────────────┴─────────────────────┘
```

## Configuration

### Authentification (multi-utilisateurs)

Le système supporte plusieurs utilisateurs. Chaque utilisateur a ses propres credentials.

**Mode interactif (menu) :**
```bash
sh setup_auth.sh
```

**Mode ligne de commande :**
```bash
# Lister les utilisateurs
sh setup_auth.sh list

# Ajouter un utilisateur (mot de passe auto-généré)
sh setup_auth.sh add nom_utilisateur

# Ajouter avec mot de passe spécifique
sh setup_auth.sh add nom_utilisateur mon_mot_de_passe

# Supprimer un utilisateur
sh setup_auth.sh delete nom_utilisateur
```

### Certificats SSL

```bash
# Régénérer les certificats
rm -rf ssl/
sh setup_ssl.sh
```

### Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `LLAMA_PORT` | 8088 | Port interne llama.cpp |
| `PDF_PORT` | 8089 | Port interne PDF service |
| `PROXY_PORT` | 5020 | Port HTTP (redirige) |
| `PROXY_PORT_SSL` | 5021 | Port HTTPS |

## Structure des fichiers

```
llama/
├── install.sh          # Script d'installation principal
├── setup_auth.sh       # Configuration authentification
├── setup_ssl.sh        # Génération certificats SSL
├── docker-compose.yaml # Orchestration Docker
├── nginx.conf          # Configuration reverse proxy
├── .htpasswd           # Credentials (généré, ignoré par git)
├── ssl/                # Certificats SSL (généré, ignoré par git)
│   ├── server.crt
│   └── server.key
├── models/             # Modèles GGUF (téléchargés, ignoré par git)
└── pdf_service/        # Service d'analyse PDF
    ├── Dockerfile
    ├── app.py          # API FastAPI
    ├── requirements.txt
    └── static/
        └── index.html  # Interface web
```

## Commandes Docker

```bash
# Démarrer (mode texte)
docker compose --profile text up -d

# Démarrer (mode vision/LLaVA)
docker compose --profile vision up -d

# Arrêter
docker compose --profile text down
docker compose --profile vision down

# Logs
docker compose logs -f

# État
docker compose ps
```

## Sécurité

- **HTTPS/TLS** : Chiffrement des communications (TLS 1.2/1.3)
- **HSTS** : Force l'utilisation de HTTPS
- **HTTP Basic Auth** : Authentification sur tous les endpoints
- **Rate Limiting** : 10 req/s API, 2 req/s uploads
- **Security Headers** : X-Frame-Options, CSP, X-Content-Type-Options
- **Container Isolation** : read_only, no-new-privileges, tmpfs

## Prérequis

- Docker & Docker Compose
- 8-16 GB RAM (selon le modèle)
- ~6 GB espace disque (modèle + conteneurs)
- OpenSSL (pour génération certificats)

## Dépannage

### Le serveur ne démarre pas
```bash
# Vérifier les logs
docker compose logs llama-server

# Vérifier la mémoire disponible
free -h
```

### Erreur de certificat dans le navigateur
C'est normal avec un certificat auto-signé. Cliquez sur "Avancé" puis "Continuer".

### Timeout sur les requêtes longues
Le proxy est configuré avec un timeout de 300 secondes. Pour les très longs documents, augmentez `proxy_read_timeout` dans `nginx.conf`.

## Licence

MIT
