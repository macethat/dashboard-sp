-- ==========================================
-- SUPABASE SCHEMA - Suplementos Panamá
-- ==========================================
-- Ejecutar en el SQL Editor de Supabase
-- ==========================================

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  "desc" TEXT DEFAULT '',
  status TEXT DEFAULT 'pendiente',
  priority TEXT DEFAULT 'media',
  assignee TEXT DEFAULT '',
  due_date TEXT DEFAULT '',
  project_id TEXT DEFAULT '',
  tags TEXT[] DEFAULT '{}',
  stage TEXT DEFAULT 'planificacion',
  progress INTEGER DEFAULT 0,
  created TEXT DEFAULT '',
  incidents JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  "desc" TEXT DEFAULT '',
  start TEXT DEFAULT '',
  "end" TEXT DEFAULT '',
  owner TEXT DEFAULT '',
  color TEXT DEFAULT '#0066ff',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT DEFAULT '#3498db',
  "desc" TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS connections (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  target TEXT NOT NULL,
  type TEXT DEFAULT 'dependencia',
  notes TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reports (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  date TEXT DEFAULT '',
  data JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (safe to run multiple times)
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (safe to re-create)
DROP POLICY IF EXISTS "Allow all on tasks" ON tasks;
DROP POLICY IF EXISTS "Allow all on projects" ON projects;
DROP POLICY IF EXISTS "Allow all on tags" ON tags;
DROP POLICY IF EXISTS "Allow all on connections" ON connections;
DROP POLICY IF EXISTS "Allow all on reports" ON reports;

-- Allow all operations for anon key
CREATE POLICY "Allow all on tasks" ON tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on projects" ON projects FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on tags" ON tags FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on connections" ON connections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on reports" ON reports FOR ALL USING (true) WITH CHECK (true);
