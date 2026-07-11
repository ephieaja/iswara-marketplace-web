# SPEC.md - IKATAN SAUDAGAR AISIYIYAH JAWA TIMUR (ISWARA)

## 1. Project Overview

**Project Name:** ISWARA App
**Project Type:** Cross-platform mobile & web application (Flutter)

**Core Functionality:** Aplikasi pendataan anggota dan usaha untuk IKATAN SAUDAGAR AISIYIYAH JAWA TIMUR (ISWARA). Aplikasi ini memungkinkan pengelolaan data anggota, struktur organisasi, dan informasi usaha masing-masing anggota.

## 2. Technology Stack & Choices

### Framework & Language
- **Flutter SDK:** 3.24.0 (stable)
- **Dart:** 3.5.0
- **Target Platforms:** Web (browser) + Android (Play Store)

### Key Dependencies
- **firebase_core** - Firebase initialization
- **firebase_auth** - Authentication (login/register)
- **cloud_firestore** - Database untuk data anggota
- **firebase_storage** - Storage untuk katalog produk/foto
- **provider** - State management
- **flutter/material.dart** - UI components
- **image_picker** - Upload foto/gambar
- **intl** - Format tanggal
- **url_launcher** - Buka link sosial media
- **file_picker** - Pilih file katalog

### State Management
- **Provider** - Untuk management state aplikasi

### Architecture Pattern
- **Clean Architecture** dengan separation:
  - `lib/models/` - Data models
  - `lib/services/` - Firebase services
  - `lib/providers/` - State management
  - `lib/screens/` - UI screens
  - `lib/widgets/` - Reusable widgets

### Backend
- **Firebase** - Free tier (Firestore + Auth + Storage)

## 3. Feature List

### Authentication
- [x] Login dengan email & password
- [x] Register akun baru
- [x] Logout
- [x] Reset password via email

### Data Anggota
- [x] No. Anggota ISWARA (auto-generate)
- [x] Nama Anggota
- [x] Alamat
- [x] No. Telepon
- [x] Email
- [x] Daerah
- [x] Jabatan Organisasi (hierarki)
- [x] Username & Password

### Struktur Organisasi
```
Pimpinan Wilayah
    └── Bidang
         └── Daerah
              └── Nama Daerah
                   └── Bidang
                        └── Anggota Iswara
```

### Jenis Usaha
- [x] Jenis Usaha
- [x] Nama Usaha
- [x] Katalog Produk (upload gambar)
- [x] Akun Sosial Media (Instagram, Facebook, Tokopedia, dll)

### CRUD Operations
- [x] Tambah anggota baru
- [x] Edit data anggota
- [x] Hapus anggota
- [x] Lihat detail anggota
- [x] Daftar semua anggota

### Fitur Tambahan
- [x] Search/cari anggota
- [x] Filter berdasarkan daerah/jabatan
- [x] View profil usaha

## 4. UI/UX Design Direction

### Overall Visual Style
- **Material Design 3** dengan sentuhan Islami/Minimalis
- Clean, professional, dan mudah digunakan

### Color Scheme
- **Primary:** Hijau tua (#1B5E20) - warna Islam
- **Secondary:** Emas (#FFD700) - aksen
- **Background:** Putih/Off-white
- **Text:** Dark grey untuk readability

### Layout Approach
- **Bottom Navigation Bar** untuk mobile:
  - Beranda
  - Anggota
  - Tambah (+)
  - Usaha
  - Profil

- **Drawer Navigation** untuk web:
  - Dashboard
  - Kelola Anggota
  - Struktur Organisasi
  - Katalog Usaha
  - Pengaturan

### Key Screens
1. **Login/Register Screen** - Form authentication
2. **Dashboard** - Overview statistik
3. **Daftar Anggota** - List dengan search & filter
4. **Form Anggota** - Tambah/Edit data
5. **Detail Anggota** - View profil lengkap dengan usaha
6. **Profil Usaha** - Detail usaha dan katalog

## 5. Data Structure

### User (Authentication)
```
email: String
password: String
uid: String
```

### Anggota
```
id: String (auto)
noAnggota: String (auto-generate: ISW-XXXX)
nama: String
alamat: String
noTelepon: String
email: String
daerah: String
jabatan: {
  level: String (Pimpinan/Bidang/Daerah/Anggota)
  wilayah: String
  bidang: String
  namaDaerah: String
}
tanggalDaftar: DateTime
```

### Usaha
```
id: String (auto)
anggotaId: String
jenisUsaha: String
namaUsaha: String
katalogProduk: List<String> (URLs)
sosmed: {
  instagram: String
  facebook: String
  tokopedia: String
  shopee: String
  dll: String
}
```

## 6. Deployment Strategy

### Web (Hosting)
1. `flutter build web`
2. Upload ke hosting (Firebase Hosting / Netlify / Vercel / shared hosting)

### Android (Play Store)
1. `flutter build apk --release`
2. Upload APK/AAB ke Google Play Console

---

*Last Updated: July 2026*
