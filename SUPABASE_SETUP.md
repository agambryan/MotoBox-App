# Setup Supabase untuk MotoBox App

## Masalah yang Diselesaikan
Sebelumnya, data motor hilang saat uninstall/install ulang aplikasi karena hanya tersimpan di **SQLite local database**. Sekarang data akan **otomatis tersinkronisasi ke Supabase (cloud)** sehingga data tidak hilang meskipun aplikasi di-uninstall.

## Cara Kerja Sistem Sync

### 1. **Dual Storage System**
- **SQLite (Local)**: Untuk performa cepat dan offline access
- **Supabase (Cloud)**: Untuk backup dan sync antar device

### 2. **Auto-Sync Flow**
```
User Action → SQLite (Local) → Background Sync → Supabase (Cloud)
                    ↓                                   ↓
              Instant Response                   Safe Backup
```

### 3. **Auto-Restore Flow**
```
User Login → Check Supabase → Download Data → Restore to SQLite → Show Data
```

## Setup Tabel Supabase

Anda perlu membuat 3 tabel utama di Supabase Dashboard:

### 1. Tabel `motors`

**PENTING**: Di Supabase, `auth.users.id` bertipe **UUID**, jadi `user_id` harus UUID juga, bukan TEXT!

```sql
CREATE TABLE motors (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  merk TEXT NOT NULL,
  model TEXT NOT NULL,
  category TEXT,
  start_odometer INTEGER DEFAULT 0,
  gambar TEXT,
  gambar_url TEXT,
  harga INTEGER DEFAULT 0,
  odometer INTEGER DEFAULT 0,
  odometer_last_update INTEGER DEFAULT 0,
  fuel_level REAL DEFAULT 0,
  fuel_last_update TEXT,
  fuel_last_refill_date TEXT,
  fuel_last_refill_percent REAL,
  fuel_last_refill_odometer INTEGER,
  fuel_tank_volume_liters REAL,
  fuel_type TEXT,
  fuel_efficiency REAL DEFAULT 0,
  fuel_efficiency_source TEXT DEFAULT 'default',
  auto_increment_enabled INTEGER DEFAULT 0,
  daily_km INTEGER DEFAULT 0,
  auto_increment_enabled_date TEXT,
  location_tracking_enabled INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Create index untuk performa
CREATE INDEX idx_motors_user_id ON motors(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE motors ENABLE ROW LEVEL SECURITY;

-- Policy: User hanya bisa akses data mereka sendiri
CREATE POLICY "Users can view their own motors"
  ON motors FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own motors"
  ON motors FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own motors"
  ON motors FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own motors"
  ON motors FOR DELETE
  USING (auth.uid() = user_id);
```

### 2. Tabel `components`

```sql
CREATE TABLE components (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  motor_id TEXT NOT NULL REFERENCES motors(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  lifespan_km INTEGER NOT NULL DEFAULT 0,
  lifespan_days INTEGER NOT NULL DEFAULT 0,
  lifespan_source TEXT NOT NULL DEFAULT 'default',
  last_replacement_km INTEGER DEFAULT 0,
  last_replacement_date TEXT,
  keterangan TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Create index
CREATE INDEX idx_components_motor_id ON components(motor_id);
CREATE INDEX idx_components_user_id ON components(user_id);

-- Enable RLS
ALTER TABLE components ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own components"
  ON components FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own components"
  ON components FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own components"
  ON components FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own components"
  ON components FOR DELETE
  USING (auth.uid() = user_id);
```

### 3. Tabel `motor_photos` (Opsional)

```sql
CREATE TABLE motor_photos (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  motor_id TEXT NOT NULL REFERENCES motors(id) ON DELETE CASCADE,
  photo_path TEXT NOT NULL,
  is_primary INTEGER DEFAULT 0,
  created_at TEXT NOT NULL
);

-- Create index
CREATE INDEX idx_motor_photos_motor_id ON motor_photos(motor_id);
CREATE INDEX idx_motor_photos_user_id ON motor_photos(user_id);

-- Enable RLS
ALTER TABLE motor_photos ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own photos"
  ON motor_photos FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own photos"
  ON motor_photos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own photos"
  ON motor_photos FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own photos"
  ON motor_photos FOR DELETE
  USING (auth.uid() = user_id);
```

## Penjelasan Tipe Data

### **Mengapa `user_id` harus UUID?**

Di Supabase, tabel `auth.users` memiliki kolom `id` dengan tipe **UUID**, bukan TEXT. Karena itu:
- ✅ `user_id UUID` → Benar (kompatibel dengan `auth.users.id`)
- ❌ `user_id TEXT` → **ERROR**: foreign key incompatible types

### **Tabel `profiles` yang Sudah Ada**

Jika Anda sudah punya tabel `profiles` dengan struktur:
```sql
CREATE TABLE profiles (
  uuid UUID PRIMARY KEY,
  username TEXT,
  email TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

Tabel ini **tidak akan bentrok** dengan tabel `motors` dan `components` yang kita buat, karena:
1. `profiles` untuk data profil user (username, email, dll)
2. `motors` untuk data motor user
3. Keduanya sama-sama menggunakan `user_id UUID` yang merujuk ke `auth.users(id)`

## Cara Setup di Supabase Dashboard

### Step 1: Buka SQL Editor
1. Login ke [Supabase Dashboard](https://supabase.com/dashboard)
2. Pilih project Anda
3. Klik **SQL Editor** di sidebar kiri

### Step 2: Jalankan SQL Commands
1. Copy SQL command untuk tabel `motors` di atas (mulai dari `CREATE TABLE motors...` sampai policy terakhir)
2. Paste ke SQL Editor
3. Klik **Run** atau tekan `Ctrl+Enter`
4. Ulangi untuk tabel `components` dan `motor_photos`

**PENTING**: Jalankan satu tabel sekali run. Jangan gabung semua tabel dalam satu run untuk menghindari error.

### Step 3: Verifikasi Tabel
1. Klik **Table Editor** di sidebar
2. Pastikan 3 tabel sudah muncul:
   - ✅ `motors`
   - ✅ `components`
   - ✅ `motor_photos`

### Step 4: Cek Row Level Security
1. Di Table Editor, klik salah satu tabel
2. Klik tab **Policies**
3. Pastikan ada 4 policies (SELECT, INSERT, UPDATE, DELETE)

## Fitur yang Sudah Diimplementasi

### ✅ Auto-Sync ke Cloud
- Setiap kali user **insert/update/delete motor** → otomatis sync ke Supabase
- Setiap kali user **insert/update component** → otomatis sync ke Supabase
- Sync berjalan di **background** (non-blocking) untuk performa optimal

### ✅ Auto-Restore saat Login
- Saat user **login** → otomatis download data dari Supabase
- Data **motor** dan **component** di-restore ke local database
- User langsung bisa lihat data motor mereka

### ✅ Offline Support
- App tetap bisa digunakan **offline** (data dari SQLite local)
- Saat **online kembali** → data akan ter-sync otomatis

## Testing

### Test 1: Data Tersimpan di Cloud
1. Login ke aplikasi dengan email Anda
2. Buat motor baru
3. Buka Supabase Dashboard → Table Editor → `motors`
4. ✅ Motor Anda harus muncul di tabel

### Test 2: Data Ter-restore saat Uninstall/Install
1. **Uninstall** aplikasi dari device
2. **Install** aplikasi lagi
3. **Login** dengan email yang sama
4. ✅ Motor Anda harus muncul kembali

### Test 3: Data Ter-sync antar Device (Future)
1. Login di Device A, buat motor
2. Login di Device B dengan email yang sama
3. ✅ Motor dari Device A harus muncul di Device B

## Troubleshooting

### Problem: Data tidak muncul setelah uninstall
**Solution:**
1. Cek apakah sudah login dengan email yang benar
2. Cek internet connection
3. Cek log di Debug Console: `Failed to sync motor to cloud: ...`
4. Cek Supabase Dashboard → Table Editor → pastikan data ada di cloud

### Problem: Error "Failed to sync motor to cloud"
**Solution:**
1. Pastikan tabel Supabase sudah dibuat dengan benar
2. Pastikan Row Level Security policies sudah dibuat
3. Cek `.env` file: SUPABASE_URL dan SUPABASE_ANON_KEY harus valid
4. Cek Supabase Dashboard → Logs untuk error detail

### Problem: "UNIQUE constraint failed"
**Solution:**
- Error ini sudah diperbaiki di kode terbaru
- Pastikan Anda menggunakan versi terbaru dari `database_helper.dart`

## Technical Details

### Database Helper Functions

#### Sync Functions (Auto-triggered)
```dart
// Di database_helper.dart

// Auto-sync motor saat insert/update
void _syncMotorToCloud(Map<String, dynamic> motor, String userId)

// Auto-sync component saat insert/update
void _syncComponentToCloud(Map<String, dynamic> component, String userId)
```

#### Restore Functions (Manual call)
```dart
// Di database_helper.dart

// Restore semua motor dari cloud
Future<void> restoreMotorsFromCloud()

// Restore component untuk motor tertentu
Future<void> restoreComponentsFromCloud(String motorId)
```

### Supabase Service Functions

```dart
// Di supabase_service.dart

// Motor CRUD
Future<void> saveMotorToCloud(Map<String, dynamic> motor)
Future<List<Map<String, dynamic>>> getMotorsFromCloud()
Future<void> updateMotorInCloud(Map<String, dynamic> motor)
Future<void> deleteMotorFromCloud(String motorId)

// Component CRUD
Future<void> saveComponentsToCloud(List<Map<String, dynamic>> components)
Future<List<Map<String, dynamic>>> getComponentsFromCloud(String motorId)
```

## Flow Chart

```
┌─────────────────────────────────────────────────────────────┐
│                    User Login                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Check Supabase Auth  │
         └───────────┬───────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
   Logged In                  Not Logged In
        │                         │
        │                         └──> Redirect to Login Page
        │
        ▼
┌──────────────────────┐
│ Restore Data from    │
│ Supabase to Local DB │
└───────────┬──────────┘
            │
            ▼
    ┌───────────────┐
    │  Show Motors  │
    └───────┬───────┘
            │
┌───────────┴────────────┐
│                        │
▼                        ▼
User Add/Edit/Delete    Auto-Sync
Motor/Component         to Supabase
```

## Next Steps

1. ✅ Test uninstall/install flow
2. ✅ Verify data sync di Supabase Dashboard
3. 🔲 (Opsional) Implement photo upload ke Supabase Storage
4. 🔲 (Opsional) Implement conflict resolution (jika edit dari 2 device)
5. 🔲 (Opsional) Implement sync indicator UI

## Kesimpulan

Dengan implementasi ini, data motor Anda:
- ✅ **Aman** tersimpan di cloud (Supabase)
- ✅ **Otomatis** ter-backup setiap ada perubahan
- ✅ **Ter-restore** otomatis saat login ulang
- ✅ **Tidak hilang** meskipun uninstall aplikasi

Selama Anda login dengan **email yang sama**, data motor Anda akan selalu tersedia! 🎉
