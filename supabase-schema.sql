-- ==========================================
-- SUPABASE SCHEMA - Suplementos Panamá
-- ==========================================
-- Ejecutar en el SQL Editor de Supabase
-- ==========================================

CREATE TABLE tasks (
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

CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  "desc" TEXT DEFAULT '',
  start TEXT DEFAULT '',
  "end" TEXT DEFAULT '',
  owner TEXT DEFAULT '',
  color TEXT DEFAULT '#0066ff',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT DEFAULT '#3498db',
  "desc" TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE connections (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  target TEXT NOT NULL,
  type TEXT DEFAULT 'dependencia',
  notes TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  date TEXT DEFAULT '',
  data JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Allow all operations for anon key (since this is a single-user app)
-- In production, replace with proper auth policies
CREATE POLICY "Allow all on tasks" ON tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on projects" ON projects FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on tags" ON tags FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on connections" ON connections FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on reports" ON reports FOR ALL USING (true) WITH CHECK (true);
