# 🛒 ISWARA MARKETPLACE - POCKETBASE DEPLOYMENT GUIDE

## 📋 PRA SYARAT

1. Akun [Railway.app](https://railway.app) **atau** [Render.com](https://render.com)
2. Akun GitHub untuk menyimpan kode
3. PocketBase binary untuk Linux (download dari pocketbase.io)

---

## 🚀 CARA DEPLOY (PILIH SALAH SATU)

---

### ✅ OPTION 1: RAILWAY (PALING GAMPANG)

Railway auto-detect Dockerfile, tinggal connect GitHub.

#### Langkah:
1. **Buka** https://railway.app
2. **Login** dengan GitHub
3. **Klik** "New Project" → "Deploy from GitHub repo"
4. **Pilih** repo GitHub yang berisi folder ini
5. **Tunggu** Railway build dan deploy
6. **Dapat** URL seperti: `https://iswara-pocketbase.up.railway.app`

#### Kalau belum punya repo GitHub:
1. Buka https://github.com/new
2. Nama repo: `iswara-pocketbase`
3. Upload isi folder `pocketbase/` ini ke repo
4. Baru connect ke Railway

---

### ⚠️ OPTION 2: RENDER (BUTUH SETUP LEBIH)

Render butuh `render.yaml` Blueprint.

#### Langkah:
1. Buka https://dashboard.render.com
2. Klik "New" → "Blueprint"
3. Connect repo GitHub
4. Render auto-read `render.yaml` dan deploy
5. Dapat URL seperti: `https://iswara-pocketbase.onrender.com`

---

## 📁 FILE YANG PERLU DI UPLOAD

Kamu perlu upload isi folder `pocketbase/` ke GitHub:

```
iswara-pocketbase/
├── Dockerfile          ✅ Sudah ada
├── render.yaml         ✅ Sudah ada
├── railway.json        ✅ Sudah ada
├── pocketbase          ❌ DOWNLOAD SENDIRI
└── pb_migrations/      ✅ Sudah ada (kosong)
```

---

## ⬇️ DOWNLOAD POCKETBASE BINARY

1. Buka: https://pocketbase.io/docs/
2. Scroll ke section **"Download"**
3. Pilih **"Linux AMD64"**
4. Extract file ZIP
5. Rename file `pocketbase` (tanpa extension `.exe`)
6. Letakkan di folder ini

---

## 🔧 SETELAH DEPLOY - SETUP POCKETBASE ADMIN

1. Buka URL deployment kamu (misal: `https://xxx.railway.app/_/`)
2. Buat admin account baru
3. **Setup Collections** sesuai dengan schema yang sudah dibuat

### Collection Schema:

---

#### 1. katagori Collection (MASTER DATA)

| Field Name | Type | Options |
|------------|------|---------|
| id | Auto | - |
| created | Auto | - |
| updated | Auto | - |
| nama | Text | - |
| ikon | Text | - |

**Data kategori:**
- MakanandanMinuman
- Fashion
- kerajinanTangan
- Travel
- Buku
- Jasa
- Elektronik
- ProdukDigital
- Lainnya

---

#### 2. users Collection

Tambah field ini DI BAWAH field default (id, email, verified, etc):

| Field Name | Type | Required |
|------------|------|----------|
| name | Text | Yes |
| NamaToko | Text | Yes |
| Alamat | Text | Yes |
| Daerah | Text | Yes |
| NoWa | Text | No |
| Organisasi | Text | No |
| Tingkat | Select | No |
| Majlis | Text | No |
| NoAnggota | Text | No |

**Options untuk field "Tingkat":**
- Pusat
- Provinsi
- Kab/Kota
- Kecamatan
- Desa/Kel

---

#### 3. Produk Collection

| Field Name | Type | Required |
|------------|------|----------|
| SellerId | Text | Yes |
| NamaToko | Text | Yes |
| Nama | Text | Yes |
| Kategori | Select | Yes |
| Deskripsi | Text | Yes |
| Daerah | Text | No |
| Harga | Number | No |
| NoWa | Text | No |
| gambar | File | No |

**Options untuk field "Kategori":**
- MakanandanMinuman
- Fashion
- kerajinanTangan
- Travel
- Buku
- Jasa
- Elektronik
- ProdukDigital
- Lainnya

---

#### 4. Pesanan Collection

| Field Name | Type | Required |
|------------|------|----------|
| buyerId | Text | Yes |
| buyerName | Text | Yes |
| buyerPhone | Text | Yes |
| buyerAddress | Text | Yes |
| totalAmount | Number | Yes |
| status | Select | Yes |
| items | JSON | Yes |

**Options untuk field "status":**
- pending
- confirmed
- shipped
- completed
- cancelled

---

#### 5. interaksi Collection

| Field Name | Type | Required |
|------------|------|----------|
| idProduk | Text | Yes |
| namaProduk | Text | Yes |
| idPenjual | Text | Yes |
| NamaToko | Text | Yes |
| daerahPenjual | Text | Yes |
| namaPeminat | Text | Yes |
| noHpPeminat | Text | Yes |
| isAnonim | Bool | No |
| status | Select | Yes |

**Options untuk field "status":**
- pending
- responded
- completed

---

## 📱 UPDATE FLUTTER APP

Setelah PocketBase online:

1. Edit `lib/config/pocketbase_config.dart`
2. Ganti URL dari `http://127.0.0.1:8091` ke URL online kamu
3. Contoh:
   ```dart
   static const String pocketBaseUrl = 'https://iswara-pocketbase.up.railway.app';
   ```
4. Rebuild Flutter: `flutter build web --web-renderer html`
5. Deploy ke hosting (Vercel/Netlify/Firebase Hosting)

---

## ⚠️ PERHATIAN PENTING

### Free Tier Limitations:

**Railway Free Tier:**
- Hibernasi setelah 30 menit tidak aktif
- Data tetap aman tersimpan
- Wake up ~30 detik saat diakses lagi

**Render Free Tier:**
- Hibernasi setelah 15 menit tidak aktif
- Disk 1GB limit
- 750 jam/bulan free

### Untuk Production (Data Banyak):
- Gunakan plan berbayar
- Atau pakai VPS sendiri (DigitalOcean, AWS, dll)

---

## 🔄 ALTERNATIF: COMPOSE YML (UNTUK VPS)

Kalau mau deploy ke VPS sendiri (DigitalOcean, dll):

```yaml
version: '3.8'

services:
  pocketbase:
    build: .
    restart: unless-stopped
    ports:
      - "8091:8091"
    volumes:
      - ./pb_data:/app/pb_data
    environment:
      - TZ=Asia/Jakarta
```

Run dengan: `docker-compose up -d`

---

## 📞 BUTUH BANTUAN?

1. PocketBase Docs: https://pocketbase.io/docs/
2. Railway Docs: https://docs.railway.app
3. Render Docs: https://render.com/docs

---

**Made for ISWARA Marketplace 🌟**
