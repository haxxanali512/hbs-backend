# 🚀 Kamal Deployment Checklist

## Pre-Deployment Setup

### ✅ EC2 Instance Preparation
- [ ] EC2 instance running Ubuntu 20.04+
- [ ] Docker installed on EC2
- [ ] Docker Compose installed on EC2
- [ ] User added to docker group
- [ ] Firewall configured (ports 22, 80, 443)
- [ ] SSH key access configured

### ✅ Local Development Setup
- [ ] Docker installed locally
- [ ] Kamal gem installed (`gem install kamal`)
- [ ] Docker Hub account created
- [ ] Docker Hub access token generated

### ✅ Rails Credentials Configuration
- [ ] Rails credentials edited with production values
- [ ] Database password set
- [ ] Redis password set
- [ ] Registry credentials added
- [ ] Master key generated for production

### ✅ Kamal Configuration
- [ ] `config/deploy.yml` updated with actual values:
  - [ ] Docker Hub username
  - [ ] EC2 IP address
  - [ ] Domain name (if using SSL)
- [ ] `.kamal/secrets` file created
- [ ] Secrets file secured (`chmod 600`)
- [ ] Secrets file added to `.gitignore`

## Deployment Steps

### ✅ First-Time Deployment
- [ ] Build and push Docker image: `bin/kamal build`
- [ ] Deploy PostgreSQL: `bin/kamal accessory boot db`
- [ ] Deploy Redis: `bin/kamal accessory boot redis`
- [ ] Wait for services to start (30 seconds)
- [ ] Deploy application: `bin/kamal deploy`

### ✅ Verification
- [ ] Check application status: `bin/kamal app details`
- [ ] View application logs: `bin/kamal app logs`
- [ ] Test API endpoint with file upload
- [ ] Access Sidekiq web UI
- [ ] Verify database connection
- [ ] Check file upload functionality

## Post-Deployment

### ✅ Monitoring Setup
- [ ] Set up application monitoring
- [ ] Configure log aggregation
- [ ] Set up alerting for critical issues
- [ ] Monitor disk space usage

### ✅ Backup Strategy
- [ ] Configure database backups
- [ ] Set up file storage backups
- [ ] Test backup restoration process
- [ ] Document backup procedures

### ✅ Security Hardening
- [ ] Review firewall rules
- [ ] Update system packages
- [ ] Configure log rotation
- [ ] Set up intrusion detection
- [ ] Regular security updates

## Troubleshooting Commands

```bash
# Check application status
bin/kamal app details

# View logs
bin/kamal app logs

# Access Rails console
bin/kamal app exec --interactive --reuse "bin/rails console"

# Check running containers
bin/kamal app exec "docker ps"

# Check disk space
bin/kamal app exec "df -h"

# Restart services
bin/kamal app stop
bin/kamal app start

# Check database connection
bin/kamal app exec "bin/rails dbconsole"
```

## Environment Variables Reference

| Variable | Description | Source |
|----------|-------------|---------|
| `RAILS_MASTER_KEY` | Rails master key | Rails credentials |
| `DATABASE_PASSWORD` | PostgreSQL password | Rails credentials |
| `REDIS_PASSWORD` | Redis password | Rails credentials |
| `KAMAL_REGISTRY_PASSWORD` | Docker Hub token | Manual setup |
| `DATABASE_HOST` | Database host | Kamal config |
| `REDIS_URL` | Redis connection URL | Kamal config |
| `API_FORMAT` | API response format | Kamal config |

## Quick Commands

```bash
# Full deployment
bin/kamal build && bin/kamal deploy

# Update only application (keep accessories running)
bin/kamal deploy

# View all services
bin/kamal app details

# Access shell
bin/kamal app exec --interactive --reuse "bash"

# View Sidekiq logs
bin/kamal app logs -r job
```

## Emergency Procedures

### If deployment fails:
1. Check logs: `bin/kamal app logs`
2. Verify services: `bin/kamal app details`
3. Check EC2 instance: SSH and run `docker ps`
4. Restart services: `bin/kamal app stop && bin/kamal app start`

### If database issues:
1. Check PostgreSQL logs: `bin/kamal accessory logs db`
2. Verify database connection
3. Check disk space
4. Restart database: `bin/kamal accessory boot db`

### If Redis issues:
1. Check Redis logs: `bin/kamal accessory logs redis`
2. Verify Redis connection
3. Restart Redis: `bin/kamal accessory boot redis`
