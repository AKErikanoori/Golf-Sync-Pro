# Standar Arsitektur Enterprise GolfSync PRO (Tier A)

Dokumen ini adalah checklist kepatuhan arsitektur enterprise untuk sistem GolfSync PRO mengacu pada 8 Pilar Standar Arsitektur (AGENTS.md Bagian II Poin 16).

---

## 1. Fungsional
- [x] **Penerapan Dynamic RBAC**: Role `super-admin`, `host`, dan `player` dikelola lewat tabel database (`roles`, `permissions`, `role_permissions`, `user_roles`).
- [x] **Pencatatan Jejak Audit**: Tabel `global_audit_logs` mencatat seluruh mutasi dan aktivitas sistem (Poin 11 SOP).
- [x] **Kontrol Konkurensi Data**: Menggunakan Supabase Realtime channel + optimasi delta patch.

## 2. Kebutuhan Non-Fungsional (NFR)
- [x] **Performa Respon**: Target respon API < 200ms menggunakan CDN dan indeks database pada kolom `id`, `email`, `code`, `is_active`.
- [x] **Ketersediaan Tinggi (HA)**: Infrastruktur terdistribusi melalui Supabase Cloud (PostgreSQL replication) dan Vercel Edge Network.
- [x] **Kemudahan Perawatan**: Struktur modular, skema database tunggal (`docs/schema.sql`), dan dokumentasi per modul.

## 3. Keamanan & ISO 27001
- [x] **Enkripsi Data in Transit**: TLS 1.3 pada seluruh endpoint Supabase dan Vercel/Firebase.
- [x] **Nol Backdoor / Bypass**: Semua alur autentikasi divalidasi ke GoTrue / Supabase Auth dengan kata sandi ter-hash (bcrypt/Argon2).
- [x] **Proteksi Akses**: Row Level Security (RLS) diaktifkan pada seluruh tabel publik PostgreSQL.

## 4. Tata Kelola Data
- [x] **Integritas Relasional**: Kunci asing (*Foreign Keys*) dengan referensi `ON DELETE CASCADE` atau `ON DELETE SET NULL`.
- [x] **Single Source of Truth**: Seluruh struktur database terdokumentasi di `docs/schema.sql`.
- [x] **Privasi Data**: Sesuai UU PDP Indonesia; data pribadi terlindungi dan tidak diekspos sembarangan.

## 5. Integrasi
- [x] **Realtime WebSockets**: Sinkronisasi skor live turnamen antar perangkat.
- [x] **PWA & Hybrid Android**: Dukungan penuh Progressive Web App dan Capacitor Android wrapper.

## 6. Kepatuhan Regulasi
- [x] Jejak audit tersimpan dengan identitas pemanggil, alamat IP, timestamp, durasi, dan kode status.

## 7. Operasional & Dukungan
- [x] Indikator status koneksi (*Sync Status*: Connected, Connecting, Error).
- [x] Console log terstruktur dan penanganan kesalahan dengan pesan ramah pengguna.

## 8. Isolasi Infrastruktur
- [x] File sensitif dan konfigurasi hosting terlindungi dari akses publik via `firebase.json` ignore list.
