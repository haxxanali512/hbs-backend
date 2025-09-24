# HBS Data Processing API

A Rails API application for processing large Excel and CSV files using Sidekiq for background job processing.

## Features

- **File Upload API**: Upload Excel (.xlsx, .xls) and CSV files via REST API
- **Background Processing**: Uses Sidekiq to process large files with millions of records
- **Data Processing**: 
  - Patient name formatting (Last, First → First Last)
  - Payment grouping and CARC code mapping
  - Currency parsing and validation
- **API Integration**: Automatically sends processed data to external API
- **CSV Export**: Generates and saves CSV files to public folder for download
- **PostgreSQL Database**: Production-ready database configuration
- **Redis**: For Sidekiq job queue management
- **Manual Deployment**: Ready for manual deployment to any server

## API Endpoints

### Upload File
```
POST /api/v1/file_uploads
Content-Type: multipart/form-data

Parameters:
- file: Excel or CSV file (max 100MB)

Response:
{
  "message": "File uploaded successfully and processing started",
  "job_id": "uuid",
  "file_type": "csv|xlsx|xls",
  "status": "queued"
}
```

### Check Job Status
```
GET /api/v1/file_uploads/status?job_id=uuid

Response:
{
  "job_id": "uuid",
  "status": "processing",
  "message": "Check Sidekiq dashboard for detailed status"
}
```

### Sidekiq Dashboard
```
GET /sidekiq
```

## Local Development Setup

### Prerequisites
- Ruby 3.2.0
- PostgreSQL
- Redis

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up environment variables:
   ```bash
   # Copy the environment template
   cp config/environment.template .env.development
   
   # Edit with your development values
   nano .env.development
   ```

4. Setup database:
   ```bash
   rails db:create
   rails db:migrate
   ```

5. Start Redis:
   ```bash
   redis-server
   ```

6. Start Sidekiq:
   ```bash
   bundle exec sidekiq
   ```

7. Start Rails server:
   ```bash
   rails server
   ```

### Environment Variables

Create a `.env` file in the root directory:

```env
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_password
DATABASE_HOST=localhost
DATABASE_PORT=5432
REDIS_URL=redis://localhost:6379/0
API_FORMAT=json  # or "csv" for CSV format
```


## Manual Production Deployment

### Prerequisites
- Server with Ruby 3.2.0+ installed
- PostgreSQL 15+ installed and running
- Redis 7.0+ installed and running
- Nginx (optional, for reverse proxy)

### Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd hbs_data_processing
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up environment variables:
   ```bash
   # Copy the environment template
   cp config/environment.template .env.production
   
   # Edit with your production values
   nano .env.production
   ```

4. Configure the database:
   ```bash
   # Create the database
   rails db:create RAILS_ENV=production
   
   # Run migrations
   rails db:migrate RAILS_ENV=production
   ```

5. Precompile assets:
   ```bash
   rails assets:precompile RAILS_ENV=production
   ```

6. Start the application:
   ```bash
   # Start Rails server
   rails server -e production -p 3000
   
   # In another terminal, start Sidekiq
   bundle exec sidekiq -e production
   ```

### Environment Variables

Create a `.env.production` file with:
```
DATABASE_HOST=localhost
DATABASE_USERNAME=your_db_user
DATABASE_PASSWORD=your_db_password
DATABASE_PORT=5432
REDIS_URL=redis://localhost:6379/0
RAILS_ENV=production
HOST=your-domain.com
ASSUME_SSL=false
FORCE_SSL=false
API_FORMAT=json
```

### Nginx Configuration (Optional)

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## File Processing

The application processes files in batches of 1000 rows to handle large files efficiently. You can customize the processing logic in `app/jobs/file_processing_job.rb`.

### Data Processing Features

1. **Patient Name Formatting**: Converts "Last, First" format to "First Last"
2. **Payment Grouping**: Groups records by key fields and collects CARC codes
3. **Status Mapping**: Maps CARC codes to payment statuses:
   - `242`, `2` → "Paid"
   - `1` → "Deductible" 
   - `0` → "Denial"
   - Unknown codes → "unknown"
   - Multiple statuses are joined with commas (e.g., "Paid, Deductible")
4. **Currency Parsing**: Removes non-numeric characters and converts to float
5. **API Integration**: Sends processed data to external API endpoint
6. **CSV Export**: Generates CSV files and saves them to `/public/exports/` folder

### Supported File Types
- CSV (.csv)
- Excel (.xlsx, .xls)

### File Size Limits
- Maximum file size: 100MB
- Configure in `app/controllers/api/v1/file_uploads_controller.rb`

### API Integration

The processed data is automatically sent to:
```
https://xhnq-ezxv-7zvm.n7d.xano.io/api:AmT5eNEe:v2/wayster_data
```

**Payload Format:**
```json
{
  "job_id": "uuid",
  "processed_at": "2024-01-01T12:00:00Z",
  "record_count": 1000,
  "csv_file_path": "/exports/processed_payments_uuid_20240101_120000.csv",
  "csv_download_url": "https://your-domain.com/exports/processed_payments_uuid_20240101_120000.csv",
  "data": [
    {
      "patient": "John Doe",
      "Encounter_Date": "2024-01-01",
      "Encounter_Date2": "2024-01-02",
      "organization": "Account Name",
      "Amount": 100.0,
      "carc": "1, 242",
      "Date_Processed": "2024-01-01",
      "Date_Logged": "2024-01-01",
      "procedure_code": "12345",
      "owned_by": 1,
      "payment_status": "Deductible, Paid"
    }
  ]
}
```

**CSV Export:**
- Files are saved to `/public/exports/` folder
- Filename format: `processed_payments_{job_id}_{timestamp}.csv`
- Files are accessible via public URL: `https://your-domain.com/exports/filename.csv`

**Configuration:**
- Set `API_FORMAT=json` for JSON format (default)
- Set `API_FORMAT=csv` for CSV format

## Monitoring

- **Sidekiq Dashboard**: `/sidekiq` - Monitor job queues and processing
- **Health Check**: `/up` - Application health status
- **Logs**: Check application logs in your deployment environment

## Performance Considerations

- Files are processed in batches to handle millions of records
- Temporary files are cleaned up after processing
- Consider increasing `WEB_CONCURRENCY` for high-traffic scenarios
- Monitor Redis memory usage for large job queues

## Security Notes

- Update CORS origins in production
- Use strong passwords for database and Redis
- Consider using AWS RDS for database in production
- Enable SSL/TLS in production
- Restrict file upload types and sizes

## Troubleshooting

### Common Issues

1. **Database Connection**: Ensure PostgreSQL is running and accessible
2. **Redis Connection**: Ensure Redis is running and accessible
3. **File Upload**: Check file size and type restrictions
4. **Job Processing**: Check Sidekiq logs for job failures

### Useful Commands

```bash
# Check application status
ps aux | grep rails
ps aux | grep sidekiq

# View logs
tail -f log/production.log

# Access Rails console
rails console -e production

# Restart services
# Stop and restart your Rails server and Sidekiq processes
```