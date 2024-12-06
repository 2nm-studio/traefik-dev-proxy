# Local Development Environment with Traefik

This project provides a streamlined solution for managing multiple local development projects using Traefik as a reverse proxy with HTTPS support. It allows you to run multiple Docker applications simultaneously, each with its own custom subdomains and valid SSL certificates.

## Features

- Centralized Traefik reverse proxy
- Automatic HTTPS with locally trusted certificates
- Flexible subdomain management for each project
- Shared Docker network for seamless service integration
- PowerShell scripts for automated setup
- Custom TLD support (.local by default)
- Conflict-free multi-project setup with namespaced Traefik configurations

## Prerequisites

- Windows with PowerShell
- Docker Desktop
- mkcert (for SSL certificate generation)
- Administrator privileges (for hosts file modification)

## Project Structure

```
.
├── docker-compose.yml          # Traefik configuration
├── setup-certs.ps1            # Certificate and domain management script
├── setup-traefik-network.ps1  # Docker network setup
└── certs/                     # Generated certificates directory
    ├── local-cert.pem
    └── local-key.pem
```

## Quick Start

1. Create the shared Docker network:

```powershell
.\setup-traefik-network.ps1
```

2. Start Traefik:

```powershell
docker-compose up -d
```

3. Generate certificates for your project:

```powershell
# Using default TLD (.local)
.\setup-certs.ps1 -ProjectName "myproject" -Domains "api,web,admin"

# Or with custom TLD
.\setup-certs.ps1 -ProjectName "myproject" -Domains "api,web,admin" -TLD "dev"
```

## Configuration Details

### Traefik Configuration (docker-compose.yml)

```yaml
version: "3.8"
networks:
  traefik-public:
    name: traefik-public
    external: true
services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    # ... configuration details ...
```

### Adding a Project Service

Example docker-compose.yml for your project:

```yaml
version: "3.8"
services:
  api:
    image: your-api-image
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myproject-api.rule=Host(`api.myproject.local`)"
      - "traefik.http.routers.myproject-api.tls=true"
      - "traefik.http.services.myproject-api.loadbalancer.server.port=80"

networks:
  traefik-public:
    external: true
```

### Script Usage

The `setup-certs.ps1` script supports:

- Multiple domains per project
- Custom TLD configuration
- Automatic hosts file management
- Project-namespaced Traefik configurations

Basic usage:

```powershell
.\setup-certs.ps1 -ProjectName "myproject" -Domains "api,web,admin"
```

With custom TLD:

```powershell
.\setup-certs.ps1 -ProjectName "myproject" -Domains "api,web,admin" -TLD "dev"
```

The script will:

1. Add entries to your hosts file for each domain
2. Generate SSL certificates
3. Provide Traefik configuration labels for each service

### Important Notes

1. Service Names: All Traefik routers and services are automatically namespaced with the project name to avoid conflicts. For example:

   - Router: `myproject-api`
   - Service: `myproject-api`

2. Domains: Each subdomain follows the pattern: `<service>.<project>.<tld>`
   Example: `api.myproject.local`

3. Networks: Always connect your services to the `traefik-public` network

## Example Project Setup

For a project named "penpot" with multiple services:

```powershell
.\setup-certs.ps1 -ProjectName "penpot" -Domains "app,api,postgres,redis" -TLD "local"
```

Generated Traefik configurations:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.penpot-api.rule=Host(`api.penpot.local`)"
  - "traefik.http.routers.penpot-api.tls=true"
  - "traefik.http.services.penpot-api.loadbalancer.server.port=80"
```

## Troubleshooting

1. Certificate Issues:

   - Ensure mkcert is installed and the root certificate is trusted
   - Check that the certificate files exist in the `certs/` directory

2. Network Issues:

   - Verify that the `traefik-public` network exists
   - Ensure your services are connected to the network

3. Domain Resolution:

   - Check your hosts file for correct entries
   - Clear your browser's DNS cache

4. Service Conflicts:
   - Ensure you're using the project-namespaced service names in your Traefik labels

## Security Notes

- The generated certificates are only for local development
- Traefik dashboard is accessible only locally
- The root certificate is trusted only on your development machine

## Contributing

Feel free to submit issues and enhancement requests!
