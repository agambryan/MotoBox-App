# Fix: Aplikasi Nyangkut di Splash Page

## Penyebab Masalah

Aplikasi nyangkut di splash page karena ada **inconsistency** antara nama kolom di database:

- **SQLite (Local)**: menggunakan `camelCase` (contoh: `createdAt`, `fuelLevel`, `odometerLastUpdate`)
- **Supabase (Cloud)**: seharusnya menggunakan `snake_case` (contoh: `created_at`, `fuel_level`, `odometer_last_update`)

Ketika aplikasi mencoba restore data dari Supabase saat login, query gagal karena Supabase tidak menemukan kolom dengan nama camelCase.

## Solusi yang Sudah Diterapkan

### 1. Mapping Function (di Kode)
Kode aplikasi sudah diupdate untuk otomatis convert antara camelCase (local) dan snake_case (cloud):

- **Saat sync ke cloud**: `_mapMotorToCloud()` convert camelCase → snake_case
- **Saat restore dari cloud**: `_mapMotorFromCloud()` convert snake_case → camelCase

### 2. Update Tabel Supabase (Perlu Dilakukan Manual)

Anda perlu menjalankan SQL migration di Supabase untuk mengupdate struktur tabel.

## Langkah-Langkah Perbaikan

### Step 1: Backup Data (Opsional tapi Disarankan)

Jika Anda sudah punya data di Supabase, export dulu:

1. Buka Supabase Dashboard → Table Editor
2. Pilih tabel `motors`
3. Klik tombol **Export** (biasanya di pojok kanan atas)
4. Download CSV sebagai backup

### Step 2: Jalankan Migration SQL

1. Buka Supabase Dashboard
2. Klik **SQL Editor** di sidebar kiri
3. Klik **+ New Query**
4. Copy-paste isi file `supabase_migration.sql`
5. Klik **Run** atau tekan `Ctrl+Enter`

**PENTING**:
- SQL script akan **drop table** yang lama dan buat yang baru
- Jika Anda punya data penting, jangan lupa backup dulu (Step 1)
- Atau skip baris `DROP TABLE` di SQL script dan rename table secara manual

### Step 3: Verifikasi

Setelah menjalankan migration, verifikasi bahwa kolom sudah benar:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'motors'
ORDER BY ordinal_position;
```

Kolom yang harus ada (snake_case):
- ✅ `created_at` (bukan `createdAt`)
- ✅ `updated_at` (bukan `updatedAt`)
- ✅ `fuel_level` (bukan `fuelLevel`)
- ✅ `fuel_last_update` (bukan `fuelLastUpdate`)
- ✅ `odometer_last_update` (bukan `odometerLastUpdate`)
- ✅ `auto_increment_enabled` (bukan `autoIncrementEnabled`)
- ✅ `daily_km` (bukan `dailyKm`)
- ✅ `auto_increment_enabled_date` (bukan `autoIncrementEnabledDate`)
- ✅ `location_tracking_enabled` (bukan `locationTrackingEnabled`)

### Step 4: Test Aplikasi

1. Uninstall aplikasi dari device
2. Install ulang aplikasi
3. Login dengan email Anda
4. **Aplikasi seharusnya tidak nyangkut lagi** dan langsung masuk ke homepage

## Alternatif: Jika Tidak Ingin Drop Table

Jika Anda ingin mempertahankan data yang sudah ada, gunakan `ALTER TABLE` untuk rename kolom:

```sql
-- Rename columns satu per satu
ALTER TABLE motors RENAME COLUMN "createdAt" TO created_at;
ALTER TABLE motors RENAME COLUMN "updatedAt" TO updated_at;
ALTER TABLE motors RENAME COLUMN "odometerLastUpdate" TO odometer_last_update;
ALTER TABLE motors RENAME COLUMN "fuelLevel" TO fuel_level;
ALTER TABLE motors RENAME COLUMN "fuelLastUpdate" TO fuel_last_update;
ALTER TABLE motors RENAME COLUMN "autoIncrementEnabled" TO auto_increment_enabled;
ALTER TABLE motors RENAME COLUMN "dailyKm" TO daily_km;
ALTER TABLE motors RENAME COLUMN "autoIncrementEnabledDate" TO auto_increment_enabled_date;
ALTER TABLE motors RENAME COLUMN "locationTrackingEnabled" TO location_tracking_enabled;

-- Add missing columns
ALTER TABLE motors ADD COLUMN IF NOT EXISTS fuel_efficiency REAL DEFAULT 0;
ALTER TABLE motors ADD COLUMN IF NOT EXISTS fuel_efficiency_source TEXT DEFAULT 'default';
```

## Troubleshooting

### Error: "column does not exist"
Berarti tabel masih menggunakan camelCase. Jalankan migration SQL.

### Error: "relation does not exist"
Berarti tabel `motors` belum dibuat. Jalankan full SQL dari `SUPABASE_SETUP.md`.

### Aplikasi masih nyangkut
1. Check console log untuk error message
2. Pastikan internet connection aktif
3. Pastikan Supabase credentials benar di `.env`
4. Coba logout → login lagi

## Summary

**Root Cause**: Inconsistency nama kolom (camelCase vs snake_case)
**Fix**:
- ✅ Kode sudah diupdate dengan mapping function
- ⏳ Perlu update struktur tabel Supabase (jalankan `supabase_migration.sql`)

Setelah migration selesai, aplikasi akan berfungsi normal dan tidak nyangkut lagi di splash page.
