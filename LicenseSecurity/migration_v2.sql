-- Run once against the EXISTING database created for worker.txt.
-- If the public_key column already exists, skip the ALTER TABLE statement.
ALTER TABLE devices ADD COLUMN public_key TEXT;
CREATE TABLE IF NOT EXISTS license_challenges (
  id TEXT PRIMARY KEY,
  challenge_hash TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL,
  action TEXT NOT NULL CHECK(action IN ('register','verify')),
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  consumed_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_license_challenges_device_time ON license_challenges(device_id, created_at);
CREATE INDEX IF NOT EXISTS idx_license_challenges_expiry ON license_challenges(expires_at);
