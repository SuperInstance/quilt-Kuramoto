-- scrap-quilt D1 schema
CREATE TABLE IF NOT EXISTS cells (
  sheet_id TEXT NOT NULL,
  id TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'value',
  value TEXT,
  value_type TEXT,
  t INTEGER NOT NULL DEFAULT 0,
  author TEXT NOT NULL DEFAULT 'game',
  created_at INTEGER,
  updated_at INTEGER,
  metadata TEXT,
  PRIMARY KEY (sheet_id, id)
);

CREATE TABLE IF NOT EXISTS history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sheet_id TEXT NOT NULL,
  cell_id TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  t INTEGER NOT NULL,
  author TEXT,
  created_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_history_sheet_t ON history (sheet_id, t);
CREATE INDEX IF NOT EXISTS idx_history_cell ON history (sheet_id, cell_id, t);

CREATE TABLE IF NOT EXISTS sheet_meta (
  sheet_id TEXT PRIMARY KEY,
  t INTEGER,
  tick_count INTEGER,
  updated_at INTEGER
);

-- the tapestry record: every real-board flash, one durable row
CREATE TABLE IF NOT EXISTS flash_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sheet_id TEXT NOT NULL,
  hex_hash TEXT NOT NULL,
  board TEXT NOT NULL,
  size INTEGER,
  source TEXT,
  t INTEGER,
  created_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_flash_sheet ON flash_log (sheet_id, created_at);

-- pincher cache ledger for Spark /chat
CREATE TABLE IF NOT EXISTS chat_ledger (
  hash TEXT PRIMARY KEY,
  question TEXT,
  answer TEXT,
  model TEXT,
  tokens INTEGER,
  hits INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER
);

-- yard-band skeleton: bar blobs, one row per (room, bar, voice)
-- pending at commit → frozen at freeze (tick N freezes bar N+1)
CREATE TABLE IF NOT EXISTS band_bars (
  room TEXT NOT NULL,
  bar INTEGER NOT NULL,
  voice TEXT NOT NULL,
  events_json TEXT NOT NULL DEFAULT '[]',  -- 16th-grid onsets: [{t,p,d,v},…]
  status TEXT NOT NULL DEFAULT 'pending',  -- pending | frozen
  kind TEXT,                               -- ok | shell | rest (final outcome)
  committed_at INTEGER,
  deadline_at INTEGER,
  frozen_at INTEGER,
  PRIMARY KEY (room, bar, voice)
);
CREATE INDEX IF NOT EXISTS idx_band_bars_room ON band_bars (room, bar);

-- one row per completed soak: the alarm-reliability evidence
CREATE TABLE IF NOT EXISTS band_soaks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  room TEXT NOT NULL,
  started_at INTEGER,
  ended_at INTEGER,
  tempo INTEGER,
  bar_ms INTEGER,
  bars INTEGER,
  stats_json TEXT,
  summary_json TEXT,
  created_at INTEGER
);
