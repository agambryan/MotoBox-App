-- Migration Script: Update Motors Table to Use snake_case
-- Run this SQL in Supabase SQL Editor to fix column naming inconsistency

-- Step 1: If you already have motors table with camelCase columns, drop it
-- WARNING: This will delete all data! Skip this if you want to keep data
-- DROP TABLE IF EXISTS motors CASCADE;

-- Step 2: Create motors table with correct snake_case naming
CREATE TABLE IF NOT EXISTS motors (
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
CREATE INDEX IF NOT EXISTS idx_motors_user_id ON motors(user_id);

-- Enable Row Level Security (RLS)
ALTER TABLE motors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own motors" ON motors;
DROP POLICY IF EXISTS "Users can insert their own motors" ON motors;
DROP POLICY IF EXISTS "Users can update their own motors" ON motors;
DROP POLICY IF EXISTS "Users can delete their own motors" ON motors;

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

-- Verify table structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'motors'
ORDER BY ordinal_position;
