# 🚀 Kamal Deployment Setup Guide

This guide will help you deploy your Rails application to EC2 using Kamal with Rails credentials for secure environment variable management.

## Prerequisites

1. **EC2 Instance**: Running Ubuntu 20.04+ with Docker installed
2. **Domain Name**: For SSL certificate (optional but recommended)
3. **Docker Hub Account**: For container registry
4. **SSH Access**: To your EC2 instance

## Step 1: Prepare Your EC2 Instance

### 1.1 Install Docker on EC2

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again to apply group changes
exit
```

### 1.2 Configure Firewall

```bash
# Allow SSH, HTTP, and HTTPS
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable
```

## Step 2: Configure Rails Credentials

### 2.1 Edit Rails Credentials

```bash
# Edit credentials in your local development environment
EDITOR="code --wait" bin/rails credentials:edit
```

### 2.2 Add Required Credentials

Add these to your `config/credentials.yml.enc`:

```yaml
# Database credentials
database:
  production:
    password: your_secure_database_password

# Redis credentials  
redis:
  password: your_secure_redis_password

# Registry credentials (Docker Hub)
registry:
  username: your_dockerhub_username
  password: your_dockerhub_token

# Rails master key (already exists)
# This is automatically managed by Rails
```

### 2.3 Generate Master Key for Production

```bash
# Generate a new master key for production
bin/rails credentials:show --environment=production
```

## Step 3: Update Kamal Configuration

### 3.1 Update config/deploy.yml

Replace the placeholder values in your `config/deploy.yml`:

```yaml
# Name of your application
service: hbs_data_processing

# Your Docker Hub image name
image: your-dockerhub-username/hbs_data_processing

# Your EC2 server IP
servers:
  web:
    - YOUR_EC2_IP_ADDRESS
  job:
    hosts:
      - YOUR_EC2_IP_ADDRESS
    cmd: bundle exec sidekiq

# Your domain name (optional)
proxy:
  ssl: true
  host: your-domain.com

# Registry credentials from Rails credentials
registry:
  username: <%= Rails.application.credentials.registry[:username] %>
  password:
    - KAMAL_REGISTRY_PASSWORD

# Environment variables
env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_PASSWORD
    - REDIS_PASSWORD
  clear:
    DATABASE_HOST: hbs_data_processing-db
    DATABASE_USERNAME: postgres
    DATABASE_PORT: 5432
    REDIS_URL: redis://hbs_data_processing-redis:6379/0
    WEB_CONCURRENCY: 2
    RAILS_LOG_LEVEL: info
    API_FORMAT: json

# Accessories (PostgreSQL and Redis)
accessories:
  db:
    image: postgres:15
    host: YOUR_EC2_IP_ADDRESS
    port: "127.0.0.1:5432:5432"
    env:
      clear:
        POSTGRES_DB: hbs_data_processing_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
  redis:
    image: redis:7.0
    host: YOUR_EC2_IP_ADDRESS
    port: "127.0.0.1:6379:6379"
    env:
      secret:
        - REDIS_PASSWORD
    directories:
      - data:/data
```

## Step 4: Create Kamal Secrets

### 4.1 Create .kamal/secrets file

```bash
# Create the secrets directory
mkdir -p .kamal

# Create secrets file
cat > .kamal/secrets << EOF
# Rails master key
RAILS_MASTER_KEY=your_rails_master_key_here

# Database password
DATABASE_PASSWORD=your_database_password_here

# Redis password  
REDIS_PASSWORD=your_redis_password_here

# PostgreSQL password
POSTGRES_PASSWORD=your_database_password_here

# Docker Hub registry password/token
KAMAL_REGISTRY_PASSWORD=your_dockerhub_token_here
EOF
```

### 4.2 Secure the secrets file

```bash
# Make sure only you can read the secrets file
chmod 600 .kamal/secrets

# Add to .gitignore to prevent accidental commits
echo ".kamal/secrets" >> .gitignore
```

## Step 5: Deploy with Kamal

### 5.1 First-time setup

```bash
# Build and push the Docker image
bin/kamal build

# Deploy accessories (PostgreSQL and Redis) first
bin/kamal accessory boot db
bin/kamal accessory boot redis

# Wait a moment for services to start
sleep 30

# Deploy the application
bin/kamal deploy
```

### 5.2 Subsequent deployments

```bash
# For regular deployments
bin/kamal deploy

# To see deployment status
bin/kamal app details

# To view logs
bin/kamal app logs

# To access Rails console
bin/kamal app exec --interactive --reuse "bin/rails console"
```

## Step 6: Verify Deployment

### 6.1 Check application status

```bash
# Check if all services are running
bin/kamal app details

# Check logs
bin/kamal app logs

# Test the API endpoint
curl -X POST http://your-domain.com/api/v1/file_uploads \
  -F "file=@test_file.csv" \
  -H "Content-Type: multipart/form-data"
```

### 6.2 Access Sidekiq Web UI

Visit: `http://your-domain.com/sidekiq`

## Step 7: SSL Certificate (Optional)

If you have a domain name, Kamal can automatically set up SSL:

```bash
# Update your domain in config/deploy.yml
proxy:
  ssl: true
  host: your-domain.com

# Redeploy to enable SSL
bin/kamal deploy
```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure your EC2 user is in the docker group
2. **Registry Authentication**: Verify your Docker Hub credentials
3. **Database Connection**: Check if PostgreSQL is running and accessible
4. **File Upload Issues**: Ensure the uploads directory has proper permissions

### Useful Commands

```bash
# View all running containers
bin/kamal app exec "docker ps"

# Check disk space
bin/kamal app exec "df -h"

# View system logs
bin/kamal app exec "journalctl -u docker"

# Restart services
bin/kamal app stop
bin/kamal app start
```

## Security Notes

1. **Never commit secrets**: The `.kamal/secrets` file should never be committed to version control
2. **Use strong passwords**: Generate strong, unique passwords for all services
3. **Regular updates**: Keep your EC2 instance and Docker images updated
4. **Firewall**: Only open necessary ports (22, 80, 443)
5. **SSH Keys**: Use SSH key authentication instead of passwords

## Monitoring

Consider setting up monitoring for:
- Application performance
- Database performance  
- Disk space usage
- Memory usage
- Error rates

## Backup Strategy

1. **Database**: Regular PostgreSQL backups
2. **Uploaded Files**: Backup the `/rails/storage` volume
3. **Configuration**: Keep your `config/deploy.yml` and secrets in a secure location

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `bin/kamal build` | Build and push Docker image |
| `bin/kamal deploy` | Deploy application |
| `bin/kamal app logs` | View application logs |
| `bin/kamal app details` | Show application status |
| `bin/kamal accessory boot db` | Start PostgreSQL |
| `bin/kamal accessory boot redis` | Start Redis |
| `bin/kamal app exec "command"` | Run command in container |
