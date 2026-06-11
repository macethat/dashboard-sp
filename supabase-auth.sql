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

-- Admin can see all profiles, users can see their own
DROP POLICY IF EXISTS "Profiles access" ON profiles;
CREATE POLICY "Profiles access" ON profiles
  FOR ALL USING (
    auth.role() = 'service_role' OR
    auth.uid() = id OR
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
  );

-- 2. Add created_by to tasks
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS department TEXT DEFAULT '';

-- 3. Add department to projects
ALTER TABLE projects ADD COLUMN IF NOT EXISTS department TEXT DEFAULT '';
ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- 4. Replace open policies with user-aware policies
DROP POLICY IF EXISTS "Allow all on tasks" ON tasks;
DROP POLICY IF EXISTS "Allow all on projects" ON projects;
DROP POLICY IF EXISTS "Allow all on tags" ON tags;
DROP POLICY IF EXISTS "Allow all on connections" ON connections;
DROP POLICY IF EXISTS "Allow all on reports" ON reports;

-- Tasks: admins see all, editors see their dept + own, viewers see their dept
CREATE POLICY "Tasks access" ON tasks FOR ALL
  USING (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin' OR
    created_by = auth.uid() OR
    department = (SELECT department FROM profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor')
  );

-- Projects: same logic
CREATE POLICY "Projects access" ON projects FOR ALL
  USING (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin' OR
    created_by = auth.uid() OR
    department = (SELECT department FROM profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor')
  );

-- Tags: all authenticated users can read, only admins/editors can write
CREATE POLICY "Tags read" ON tags FOR SELECT
  USING (auth.role() = 'service_role' OR auth.uid() IS NOT NULL);

CREATE POLICY "Tags write" ON tags FOR INSERT
  WITH CHECK (auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor'));

CREATE POLICY "Tags update" ON tags FOR UPDATE
  USING (auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor'));

CREATE POLICY "Tags delete" ON tags FOR DELETE
  USING (auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor'));

-- Connections: same as tasks
CREATE POLICY "Connections access" ON connections FOR ALL
  USING (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IS NOT NULL
  )
  WITH CHECK (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor')
  );

-- Reports: same as tasks
CREATE POLICY "Reports access" ON reports FOR ALL
  USING (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IS NOT NULL
  )
  WITH CHECK (
    auth.role() = 'service_role' OR
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('admin', 'editor')
  );

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
