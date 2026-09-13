# GolfSync PRO ⛳

Aplikasi pencatat skor dan manajemen turnamen golf profesional berbasis Web (PWA) dan Android (Capacitor), dengan arsitektur standar enterprise **Tier A (Multi-User)**.

---

## 🌟 Fitur Utama

### 1. Pertandingan & Turnamen (Tournament Mode)
* **Realtime Synchronization**: Sinkronisasi skor antar pemain secara *live* menggunakan Supabase Realtime Channel.
* **Beragam Format Permainan**:
  * *Strokeplay*: Perhitungan gross, net, dan over/under par standar golf.
  * *One vs All (1v1 Match Play)*: Perhitungan status Up/Down/AS (All Square) lubang per lubang secara dinamis.
  * *Team Match*: Akumulasi poin tim dan perbandingan skor kolektif.
  * *Custom Pairs*: Pertandingan berpasangan dengan penentuan lawan khusus.
* **Score Sharing**: Ekspor dan cetak ringkasan scorecard serta berbagi hasil ke WhatsApp.

### 2. Pencapaian Personal (Personal Achievement)
* **Kalkulasi USGA/WHS Handicap Index** otomatis berdasarkan riwayat ronde resmi.
* **Riwayat Ronde Lapangan**: Pencatatan tanggal, nama venue, total par, dan skor gross.
* **Pelacakan Latihan Driving Range**: Durasi sesi, jumlah bola, dan catatan progres pukulan.

### 3. Fondasi Enterprise Tier A (Admin Console)
Dapat diakses oleh peran `super-admin`:
* **👥 User Management**: Siklus CRUD penuh data pengguna, toggle status aktif/suspend (*soft delete*), dan penugasan peran.
* **📜 Global Audit Logs**: Pencatatan real-time seluruh mutasi dan aktivitas request (Method, Status, Path, User, Role, Durasi, Waktu) mengacu pada standar SOP Poin 11.
* **⚙️ Site Configuration**: Parameter konfigurasi situs yang dapat diubah tanpa redeploy (`APP_NAME`, `MAINTENANCE_MODE`, `MAX_PLAYERS_PER_ROOM`, dll.).
* **🛡️ Dynamic RBAC**: Pengelolaan peran dinamis (`super-admin`, `host`, `player`) dan matriks izin (*permissions*).

---

## 📁 Struktur Direktori

```text
├── docs/
│   ├── schema.sql              # Skema database tunggal PostgreSQL / Supabase
│   └── ENTERPRISE_STANDARDS.md # Checklist kepatuhan standar enterprise
├── www/
│   ├── index.html              # Distribusi web yang dibungkus Capacitor Android
│   ├── manifest.json           # Manifest PWA
│   └── icon-*.png              # Ikon aplikasi
├── android/                    # Proyek wrapper native Android (Capacitor)
├── capacitor.config.json       # Konfigurasi Capacitor
├── firebase.json               # Konfigurasi hosting Firebase (terproteksi)
├── vercel.json                 # Konfigurasi rewrite & security headers Vercel
├── index.html                  # Aplikasi utama web PWA
└── README.md                   # Dokumentasi resmi proyek
```

---

## 🚀 Cara Menjalankan

### 1. Inisialisasi Database
1. Buka dashboard database Anda di [Supabase](https://supabase.com).
2. Jalankan skrip yang ada di `docs/schema.sql` pada **SQL Editor** Supabase.
3. Tabel `user_profiles`, `roles`, `permissions`, `global_audit_logs`, `site_configurations`, dan `shared_tournaments` akan otomatis terkonfigurasi.

### 2. Menjalankan di Web Lokal
Anda dapat menggunakan HTTP server lokal apa saja, misalnya:
```bash
# Menggunakan npx serve
npx serve .

# Atau menggunakan Python HTTP Server
python -m http.server 3000
```
Buka browser pada `http://localhost:3000`.

### 3. Build Aplikasi Android (Capacitor)
```bash
# Sinkronkan file web ke direktori Android
npx cap sync android

# Buka Android Studio untuk build APK
npx cap open android
```

---

## 🔐 Keamanan & Standar Kepatuhan
* Autentikasi terpusat melalui Supabase Auth dengan hash kata sandi aman (bcrypt) dan token JWT.
* Seluruh mutasi dilindungi Row Level Security (RLS) pada PostgreSQL.
* Konfigurasi hosting diamankan dari paparan file sensitif repositori.
