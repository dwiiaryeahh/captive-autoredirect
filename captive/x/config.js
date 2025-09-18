module.exports = {
  // API Configuration
  api: {
    baseUrl: 'https://api.gathergo.site',
    uploadEndpoint: '/upload-db',
    timeout: 30000, // 30 seconds timeout
  },

  // Database Configuration
  database: {
    filename: 'users.db',
    tableName: 'users'
  },

  // Server Configuration
  server: {
    port: process.env.PORT || 3002,
    host: '0.0.0.0'
  },

  // Upload Configuration
  upload: {
    autoUpload: true, // Automatically upload after each new entry
    retryAttempts: 3, // Number of retry attempts if upload fails
    retryDelay: 2000, // Delay between retries in milliseconds
  }
}; 