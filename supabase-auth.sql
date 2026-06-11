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
-- SELECT: admin/supervisor/editor see ALL; viewers see only their department
CREATE POLICY "Tasks select" ON tasks FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'supervisor', 'editor') OR
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
CREATE POLICY "Projects select" ON projects FOR SELECT
  USING (
    auth.role() = 'service_role' OR
    auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'supervisor', 'editor') OR
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
CREATE POLICY "Tags select" ON tags FOR SELECT
  USING (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);
CREATE POLICY "Tags insert" ON tags FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Tags update" ON tags FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Tags delete" ON tags FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));

-- Connections: all authenticated read, admin/editor write
CREATE POLICY "Connections select" ON connections FOR SELECT
  USING (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);
CREATE POLICY "Connections insert" ON connections FOR INSERT
  WITH CHECK (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Connections update" ON connections FOR UPDATE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));
CREATE POLICY "Connections delete" ON connections FOR DELETE
  USING (auth.jwt() -> 'user_metadata' ->> 'role' IN ('admin', 'editor'));

-- Reports: all authenticated read, admin/editor write
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
