-- ==========================================
-- SUPABASE AUTH & ROLES - Suplementos Panamá
-- ==========================================
-- Ejecutar DESPUÉS de supabase-schema.sql
-- ==========================================

-- 1. Profiles table (syncs with auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  role TEXT DEFAULT 'viewer' CHECK (role IN ('admin', 'editor', 'viewer', 'supervisor')),
  department TEXT DEFAULT '',
  display_name TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Admin and supervisor can see all profiles, users see their own
DROP POLICY IF EXISTS "Profiles access" ON profiles;
DROP POLICY IF EXISTS "Profiles select" ON profiles;
DROP POLICY IF EXISTS "Profiles insert" ON profiles;
DROP POLICY IF EXISTS "Profiles update" ON profiles;
DROP POLICY IF EXISTS "Profiles delete" ON profiles;
CREATE POLICY "Profiles select" ON profiles FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    auth.uid() = id OR
    auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'supervisor')
  );
-- Only admin can modify profiles
CREATE POLICY "Profiles insert" ON profiles FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin');
CREATE POLICY "Profiles update" ON profiles FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin');
CREATE POLICY "Profiles delete" ON profiles FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin');

-- 2. Add created_by to tasks
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS department TEXT DEFAULT '';

-- 3. Add department to projects
ALTER TABLE projects ADD COLUMN IF NOT EXISTS department TEXT DEFAULT '';
ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- 4. Replace open policies with user-aware policies (using JWT to avoid recursion)
DROP POLICY IF EXISTS "Allow all on tasks" ON tasks;
DROP POLICY IF EXISTS "Allow all on projects" ON projects;
DROP POLICY IF EXISTS "Allow all on tags" ON tags;
DROP POLICY IF EXISTS "Allow all on connections" ON connections;
DROP POLICY IF EXISTS "Allow all on reports" ON reports;

-- Tasks
DROP POLICY IF EXISTS "Tasks select" ON tasks;
DROP POLICY IF EXISTS "Tasks insert" ON tasks;
DROP POLICY IF EXISTS "Tasks update" ON tasks;
DROP POLICY IF EXISTS "Tasks delete" ON tasks;
-- SELECT: admin/supervisor see ALL; editors see only own; viewers see only their department
DROP POLICY IF EXISTS "Tasks select" ON tasks;
CREATE POLICY "Tasks select" ON tasks FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'supervisor') OR
    (auth.jwt() -> 'user_metadata' ->> 'role' = 'editor' AND created_by = auth.uid()) OR
    department = COALESCE(auth.jwt() -> 'user_metadata' ->> 'department', '')
  );
-- INSERT: only admin/editor
CREATE POLICY "Tasks insert" ON tasks FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
-- UPDATE: admin edits all, editor edits own
CREATE POLICY "Tasks update" ON tasks FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin' OR created_by = auth.uid())
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
-- DELETE: admin deletes all, editor deletes own
CREATE POLICY "Tasks delete" ON tasks FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin' OR created_by = auth.uid());

-- Projects
DROP POLICY IF EXISTS "Projects select" ON projects;
DROP POLICY IF EXISTS "Projects insert" ON projects;
DROP POLICY IF EXISTS "Projects update" ON projects;
DROP POLICY IF EXISTS "Projects delete" ON projects;
DROP POLICY IF EXISTS "Projects select" ON projects;
CREATE POLICY "Projects select" ON projects FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'supervisor') OR
    (auth.jwt() -> 'user_metadata' ->> 'role' = 'editor' AND created_by = auth.uid()) OR
    department = COALESCE(auth.jwt() -> 'user_metadata' ->> 'department', '')
  );
CREATE POLICY "Projects insert" ON projects FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Projects update" ON projects FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin' OR created_by = auth.uid())
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Projects delete" ON projects FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' = 'admin' OR created_by = auth.uid());

-- Tags: all authenticated can read, only admin/editor write
DROP POLICY IF EXISTS "Tags select" ON tags;
DROP POLICY IF EXISTS "Tags insert" ON tags;
DROP POLICY IF EXISTS "Tags update" ON tags;
DROP POLICY IF EXISTS "Tags delete" ON tags;
CREATE POLICY "Tags select" ON tags FOR SELECT
  USING (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);
CREATE POLICY "Tags insert" ON tags FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Tags update" ON tags FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Tags delete" ON tags FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));

-- Connections: all authenticated read, admin/editor write
DROP POLICY IF EXISTS "Connections select" ON connections;
DROP POLICY IF EXISTS "Connections insert" ON connections;
DROP POLICY IF EXISTS "Connections update" ON connections;
DROP POLICY IF EXISTS "Connections delete" ON connections;
CREATE POLICY "Connections select" ON connections FOR SELECT
  USING (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);
CREATE POLICY "Connections insert" ON connections FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Connections update" ON connections FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Connections delete" ON connections FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));

-- Reports: all authenticated read, admin/editor write
DROP POLICY IF EXISTS "Reports select" ON reports;
DROP POLICY IF EXISTS "Reports insert" ON reports;
DROP POLICY IF EXISTS "Reports update" ON reports;
DROP POLICY IF EXISTS "Reports delete" ON reports;
CREATE POLICY "Reports select" ON reports FOR SELECT
  USING (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);
CREATE POLICY "Reports insert" ON reports FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Reports update" ON reports FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Reports delete" ON reports FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));

-- 5. Auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, department, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'viewer'),
    COALESCE(NEW.raw_user_meta_data->>'department', ''),
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
