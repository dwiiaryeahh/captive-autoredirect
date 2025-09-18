# Database Upload Feature

## Overview
Fitur ini memungkinkan aplikasi captive portal untuk secara otomatis mengupload database SQLite ke subdomain API setiap kali ada data baru yang ditambahkan.

## Fitur Utama

### 1. Auto Upload
- Database akan diupload secara otomatis setiap kali user baru mengisi form login
- Upload dilakukan setelah data berhasil disimpan ke database lokal
- Mendukung retry mechanism jika upload gagal

### 2. Manual Upload
- Tombol "Upload Database" di halaman admin untuk upload manual
- Berguna untuk testing atau upload ulang jika auto-upload gagal
- Memberikan feedback real-time tentang status upload

### 3. Retry Logic
- Mencoba upload ulang hingga 3 kali jika gagal (konfigurasi)
- Delay 2 detik antara setiap percobaan
- Logging detail untuk setiap percobaan

## Konfigurasi

### File: `config.js`
```javascript
module.exports = {
  api: {
    baseUrl: 'http://database.x.com',        // URL API subdomain
    uploadEndpoint: '/upload-db',            // Endpoint untuk upload
    timeout: 10000,                          // Timeout dalam milliseconds
  },
  
  upload: {
    autoUpload: true,                        // Enable/disable auto upload
    retryAttempts: 3,                        // Jumlah percobaan ulang
    retryDelay: 2000,                        // Delay antar percobaan (ms)
  }
};
```

## Cara Kerja

### 1. Auto Upload Flow
```
User mengisi form → Data disimpan ke DB → Auto upload ke API → Redirect ke X.com
```

### 2. Manual Upload Flow
```
Admin klik "Upload Database" → Upload ke API → Feedback ke admin
```

### 3. Retry Mechanism
```
Upload gagal → Tunggu 2 detik → Coba lagi (max 3x) → Log hasil
```

## API Endpoint

### Target API: `http://database.x.com/upload-db`
- Method: `POST`
- Content-Type: `multipart/form-data`
- Field: `database` (file SQLite)

### Response Format
```json
{
  "success": true,
  "message": "Database uploaded successfully",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

## Logging

### Console Output
```
🔄 New user data added, uploading database to API...
✅ Database uploaded successfully to API
Response: { success: true, message: "Upload successful" }
```

### Error Handling
```
❌ Error uploading database to API (attempt 1): Network timeout
🔄 Retrying upload in 2000ms...
❌ Error uploading database to API (attempt 2): Connection refused
⚠️ Database upload failed after all retry attempts
```

## Dependencies

### New Dependencies
- `axios`: HTTP client untuk request ke API
- `form-data`: Untuk upload file multipart
- `fs`: File system operations (built-in)

### Installation
```bash
npm install axios form-data
```

## Troubleshooting

### 1. Upload Gagal
- Periksa koneksi internet
- Pastikan API endpoint aktif
- Cek firewall/network settings
- Verifikasi URL di `config.js`

### 2. Database File Tidak Ditemukan
- Pastikan file `xcom_users.db` ada di root directory
- Cek permission file
- Restart aplikasi jika perlu

### 3. Timeout Issues
- Increase timeout di `config.js`
- Periksa kecepatan koneksi
- Cek ukuran file database

## Security Considerations

### 1. API Security
- Implementasi authentication di API endpoint
- Gunakan HTTPS untuk transfer data
- Validasi file yang diupload

### 2. Network Security
- Firewall rules untuk API endpoint
- Rate limiting untuk mencegah abuse
- Monitoring untuk suspicious activity

## Testing

### 1. Test Auto Upload
1. Jalankan aplikasi
2. Isi form login dengan data dummy
3. Cek console untuk log upload
4. Verifikasi file terupload ke API

### 2. Test Manual Upload
1. Akses `/admin`
2. Klik "Upload Database"
3. Cek feedback di halaman
4. Verifikasi status di console

### 3. Test Retry Logic
1. Matikan API endpoint
2. Coba upload (akan gagal)
3. Nyalakan API endpoint
4. Upload akan retry otomatis 