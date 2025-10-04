# Server Hub

This repository contains Docker Compose configurations for various services following a standardized structure.

## Structure Rules

### 1. Service Organization
- Each service has its own folder under `docker_composes/`
- Each service folder contains a `compose.yaml` file (not `docker-compose.yaml`)

### 2. Environment Variables
- All environment variables are defined in the root `.env` file
- Compose files reference variables using `${VARIABLE_NAME}` syntax
- The `.env` file is included in `.gitignore` for security

### 3. File Structure
```
server-hub/
├── .env                           # Environment variables (gitignored)
├── .gitignore                     # Git ignore rules
├── setup.sh                      # Setup script
├── README.md                      # This documentation
└── docker_composes/
    ├── portainer/
    │   └── compose.yaml          # Portainer service configuration
    ├── n8n/
    │   └── compose.yaml          # N8N workflow automation
    └── [service-name]/
        └── compose.yaml          # Additional services follow same pattern
```

## Current Services

Each service is deployed via Cloudflare tunnel and configured in the Cloudflare dashboard. Service folders contain their respective `compose.yaml` files.

## Usage

1. Copy `.env.example` to `.env` and configure your environment variables
2. Navigate to the service directory you want to deploy
3. Run: `docker compose up -d`

## Adding New Services

When adding a new service:

1. Create a new folder under `docker_composes/[service-name]/`
2. Create a `compose.yaml` file inside the folder
3. Add any required environment variables to the root `.env` file
4. Update this README with service information

## Environment Variables

The `.env` file is organized into sections:

- **Global Configuration**: System-wide settings (HOME, TZ, user IDs)
- **Cloudflare Tunnel**: Authentication token for tunnel access
- **Service Domains**: Domain configurations for each service
- **Service Configurations**: Service-specific settings and credentials

All environment variables are centralized in the root `.env` file and referenced in compose files using `${VARIABLE_NAME}` syntax.

## Security

- The `.env` file contains sensitive information and is excluded from version control
- Never commit the `.env` file to the repository
- Use environment-specific `.env` files for different deployments (development, staging, production)
