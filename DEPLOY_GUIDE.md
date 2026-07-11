# 🛒 Marketplace ISWARA - Panduan Deploy

## Langkah Deploy ke Firebase Hosting

### 1️⃣ Buka Terminal
Buka Command Prompt atau PowerShell di folder project:
```
cd c:\Users\ephiewae\iswara_marketplace
```

### 2️⃣ Login Firebase
Jalankan perintah:
```
firebase login
```
- Akan terbuka browser
- Pilih akun Google Anda
- Izinkan akses Firebase CLI
- Kembali ke terminal

### 3️⃣ Initialize Firebase (jika belum)
```
firebase init hosting
```
Pilih:
- pilih folder `build/web`
- Configure as single-page app: **Yes**
- Set up automatic builds: **No**

### 4️⃣ Deploy!
```
firebase deploy --only hosting
```

### 5️⃣ Selesai! 🎉
Akan muncul URL seperti:
```
https://iswara-marketplace.web.app
```

---

## Atau gunakan alternatif lain:

### Vercel (Gratis & Mudah)
1. Buka https://vercel.com
2. Login dengan GitHub
3. Drag folder `build/web` ke Vercel
4. Selesai! Dapat URL seperti `iswara-marketplace.vercel.app`

### Netlify (Gratis)
1. Buka https://netlify.com
2. Login/Signup
3. Sites → Add new site → Deploy manually
4. Drag folder `build/web`
5. Selesai!

---

## 📁 Yang perlu di-deploy
Folder: `c:\Users\ephiewae\iswara_marketplace\build\web`

Pastikan folder `build/web` ada isinya (index.html, dll)

---

## 🔧 Jika ada error saat build
```powershell
cd c:\Users\ephiewae\iswara_marketplace
flutter clean
flutter pub get
flutter build web --web-renderer html
```

---

## 📱 Update App Setelah Edit Code
1. Edit kode
2. Build ulang:
   ```powershell
   flutter build web --web-renderer html
   ```
3. Deploy ulang:
   ```powershell
   firebase deploy --only hosting
   ```
