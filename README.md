# Local Development Environment with Traefik

This project provides a streamlined solution for managing multiple local development projects using Traefik as a reverse proxy with HTTPS support. It allows you to run multiple Docker applications simultaneously, each with its own `.local` subdomains and valid SSL certificates.

## Features

- Centralized Traefik reverse proxy
- Automatic HTTPS with locally trusted certificates
- Easy subdomain management for each project
- Shared Docker network for seamless service integration
- PowerShell scripts for automated setup

## Prerequisites

- Windows with PowerShell
- Docker Desktop
- mkcert (for SSL certificate generation)
- Administrator privileges (for hosts file modification)

## Project Structure

```
.
├── docker-compose.yml      # Traefik configuration
├── setup-certs.ps1        # Certificate management script
├── setup-traefik-network.ps1  # Docker network setup
└── certs/                 # Generated certificates directory
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
.\setup-certs.ps1 -ProjectName "myproject" -Domains "api,web,admin" -TLD "local"
```

## Adding a New Project

1. Run the certificate setup script with your project domains:

```powershell
.\setup-certs.ps1 -ProjectName "myproject" -Domains "api,web,admin"
```

2. Add the following labels to your project's Docker services:

```yaml
services:
  myservice:
    # ... other configuration ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myservice.rule=Host(`myservice.myproject.local`)"
      - "traefik.http.routers.myservice.tls=true"
      - "traefik.http.services.myservice.loadbalancer.server.port=80"
    networks:
      - traefik-public
```

## Configuration Details

### Traefik Configuration

The Traefik reverse proxy is configured with:

- HTTP (port 80) and HTTPS (port 443) endpoints
- Docker provider integration
- Automatic TLS termination
- Dashboard available at `https://traefik.local`

### Certificate Management

The `setup-certs.ps1` script:

- Generates SSL certificates using mkcert
- Updates the Windows hosts file
- Installs the root certificate
- Provides Traefik configuration examples

### Network Setup

The `setup-traefik-network.ps1` script creates a shared Docker network named `traefik-public` that allows communication between Traefik and your services.

## Example Usage

For a project named "penpot", you can set up the following subdomains:

```powershell
.\setup-certs.ps1 -ProjectName "penpot" -Domains "app,api,redis"
```

This will:

1. Create entries in your hosts file for:
   - app.penpot.local
   - api.penpot.local
   - redis.penpot.local
2. Generate SSL certificates for these domains
3. Provide the necessary Traefik configuration labels

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

## Security Notes

- The generated certificates are only for local development
- Traefik dashboard is accessible only locally
- The root certificate is trusted only on your development machine

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.
