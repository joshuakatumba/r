DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO anon; GRANT ALL ON SCHEMA public TO authenticated; GRANT ALL ON SCHEMA public TO service_role;
-- 1. Create Enums
CREATE TYPE user_role AS ENUM ('admin', 'branch_user', 'pending');
CREATE TYPE transaction_status AS ENUM ('PENDING', 'CLAIMED');

-- 2. Create Tables
CREATE TABLE public.branches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert default branches
INSERT INTO public.branches (name) VALUES ('Branch A'), ('Branch B');

CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    role user_role DEFAULT 'pending'::user_role NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    amount NUMERIC NOT NULL,
    sender_name TEXT NOT NULL,
    sender_contact TEXT NOT NULL,
    sender_address TEXT NOT NULL,
    status transaction_status DEFAULT 'PENDING'::transaction_status NOT NULL,
    branch_origin UUID REFERENCES public.branches(id) NOT NULL,
    branch_claimed UUID REFERENCES public.branches(id),
    created_by UUID REFERENCES public.users(id) NOT NULL,
    claimed_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    claimed_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE public.logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id),
    action TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Row Level Security (RLS)
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs ENABLE ROW LEVEL SECURITY;

-- Branches Policies
CREATE POLICY "Admins can do everything on branches" ON public.branches FOR ALL USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);
CREATE POLICY "Everyone can read branches" ON public.branches FOR SELECT USING (true);


-- Users Policies
CREATE POLICY "Admins can manage all users" ON public.users FOR ALL USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);
CREATE POLICY "Users can read their own profile" ON public.users FOR SELECT USING (
    id = auth.uid()
);


-- Transactions Policies
CREATE POLICY "Admins can view and manage all transactions" ON public.transactions FOR ALL USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);

CREATE POLICY "Branch users can insert transactions" ON public.transactions FOR INSERT WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'branch_user'
);

CREATE POLICY "Branch users can view their branch transactions" ON public.transactions FOR SELECT USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'branch_user' AND
    (
      branch_origin = (SELECT branch_id FROM public.users WHERE id = auth.uid()) OR
      branch_claimed = (SELECT branch_id FROM public.users WHERE id = auth.uid())
    )
);

CREATE POLICY "Branch users can update transactions to claim" ON public.transactions FOR UPDATE USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'branch_user'
);


-- Logs Policies
CREATE POLICY "Admins can view and manage all logs" ON public.logs FOR ALL USING (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
);
CREATE POLICY "Branch users can insert logs" ON public.logs FOR INSERT WITH CHECK (
    (SELECT role FROM public.users WHERE id = auth.uid()) = 'branch_user'
);
CREATE POLICY "Branch users can view their own logs" ON public.logs FOR SELECT USING (
    user_id = auth.uid()
);

-- 4. Triggers
-- Create a trigger function to automatically create a user profile in public.users on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  IF new.email = 'kabcal04@gmail.com' THEN
    INSERT INTO public.users (id, role)
    VALUES (new.id, 'admin');
  ELSE
    INSERT INTO public.users (id, role)
    VALUES (new.id, 'pending');
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
-- Add missing sender detail columns to transactions table
ALTER TABLE public.transactions 
ADD COLUMN sender_name TEXT,
ADD COLUMN sender_contact TEXT,
ADD COLUMN sender_address TEXT;
-- Backfill migration for existing projects created before sender fields were added.
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS sender_name TEXT,
  ADD COLUMN IF NOT EXISTS sender_contact TEXT,
  ADD COLUMN IF NOT EXISTS sender_address TEXT;
-- Rename existing branches to match the new naming convention
BEGIN;

UPDATE public.branches 
SET name = 'Branch A' 
WHERE name = 'Uganda';

UPDATE public.branches 
SET name = 'Branch B' 
WHERE name = 'South Sudan';

COMMIT;
-- Rename branches back to specific names
BEGIN;

UPDATE public.branches 
SET name = 'Uganda Branch' 
WHERE name = 'Branch A';

UPDATE public.branches 
SET name = 'Sudan Branch' 
WHERE name = 'Branch B';

COMMIT;
-- Add full_name and email to public.users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS email TEXT;

-- Update the handle_new_user trigger function to capture metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, role, full_name, email)
  VALUES (
    new.id, 
    CASE 
      WHEN new.email = 'kabcal04@gmail.com' THEN 'admin'::user_role 
      ELSE 'pending'::user_role 
    END,
    new.raw_user_meta_data->>'full_name',
    new.email
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Function to check if the current user is an admin without causing recursion
CREATE OR REPLACE FUNCTION public.check_is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT (role = 'admin')
    FROM public.users
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing recursive policies on public.users
DROP POLICY IF EXISTS "Admins can manage all users" ON public.users;
DROP POLICY IF EXISTS "Users can read their own profile" ON public.users;

-- Re-create policies using the helper function or simple checks
CREATE POLICY "Admins can manage all users" ON public.users 
FOR ALL USING (
    public.check_is_admin()
);

CREATE POLICY "Users can read their own profile" ON public.users 
FOR SELECT USING (
    id = auth.uid()
);

-- Ensure public.users has the correct columns (in case 04 migration was missed)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='full_name') THEN
        ALTER TABLE public.users ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email') THEN
        ALTER TABLE public.users ADD COLUMN email TEXT;
    END IF;
END $$;
-- Remove deprecated Admin Branch option from database
DO $$
DECLARE
  admin_branch_id UUID;
BEGIN
  SELECT id INTO admin_branch_id
  FROM public.branches
  WHERE name = 'Admin Branch'
  LIMIT 1;

  IF admin_branch_id IS NULL THEN
    RETURN;
  END IF;

  -- Detach users assigned to Admin Branch
  UPDATE public.users
  SET branch_id = NULL
  WHERE branch_id = admin_branch_id;

  -- Prevent orphaning transaction references
  IF EXISTS (
    SELECT 1
    FROM public.transactions
    WHERE branch_origin = admin_branch_id OR branch_claimed = admin_branch_id
  ) THEN
    RAISE EXCEPTION 'Cannot remove Admin Branch because it is referenced by transactions. Reassign those records first.';
  END IF;

  DELETE FROM public.branches
  WHERE id = admin_branch_id;
END
$$;
-- Capture extra onboarding fields and keep only supported branches.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'first_name') THEN
    ALTER TABLE public.users ADD COLUMN first_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'last_name') THEN
    ALTER TABLE public.users ADD COLUMN last_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'contact') THEN
    ALTER TABLE public.users ADD COLUMN contact TEXT;
  END IF;
END $$;

UPDATE public.users
SET
  first_name = COALESCE(first_name, split_part(COALESCE(full_name, ''), ' ', 1)),
  last_name = COALESCE(last_name, NULLIF(trim(substr(COALESCE(full_name, ''), length(split_part(COALESCE(full_name, ''), ' ', 1)) + 1)), '')),
  full_name = trim(
    COALESCE(NULLIF(first_name, ''), '') || ' ' || COALESCE(NULLIF(last_name, ''), '')
  )
WHERE first_name IS NULL OR last_name IS NULL;

DO $$
DECLARE
  uganda_id UUID;
  sudan_id UUID;
  old_id UUID;
BEGIN
  SELECT id INTO uganda_id FROM public.branches WHERE name = 'Uganda Branch' LIMIT 1;
  IF uganda_id IS NULL THEN
    INSERT INTO public.branches (name) VALUES ('Uganda Branch') RETURNING id INTO uganda_id;
  END IF;

  FOR old_id IN SELECT id FROM public.branches WHERE name IN ('Branch A', 'Uganda') LOOP
    IF old_id <> uganda_id THEN
      UPDATE public.users SET branch_id = uganda_id WHERE branch_id = old_id;
      UPDATE public.transactions SET branch_origin = uganda_id WHERE branch_origin = old_id;
      UPDATE public.transactions SET branch_claimed = uganda_id WHERE branch_claimed = old_id;
      DELETE FROM public.branches WHERE id = old_id;
    END IF;
  END LOOP;

  SELECT id INTO sudan_id FROM public.branches WHERE name = 'Sudan Branch' LIMIT 1;
  IF sudan_id IS NULL THEN
    INSERT INTO public.branches (name) VALUES ('Sudan Branch') RETURNING id INTO sudan_id;
  END IF;

  FOR old_id IN SELECT id FROM public.branches WHERE name IN ('Branch B', 'South Sudan', 'Sudan') LOOP
    IF old_id <> sudan_id THEN
      UPDATE public.users SET branch_id = sudan_id WHERE branch_id = old_id;
      UPDATE public.transactions SET branch_origin = sudan_id WHERE branch_origin = old_id;
      UPDATE public.transactions SET branch_claimed = sudan_id WHERE branch_claimed = old_id;
      DELETE FROM public.branches WHERE id = old_id;
    END IF;
  END LOOP;

  DELETE FROM public.branches WHERE name IN ('Branch A', 'Branch B');
END $$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  meta_first_name TEXT;
  meta_last_name TEXT;
  meta_full_name TEXT;
BEGIN
  meta_first_name := COALESCE(new.raw_user_meta_data->>'first_name', '');
  meta_last_name := COALESCE(new.raw_user_meta_data->>'last_name', '');
  meta_full_name := trim(
    COALESCE(NULLIF(meta_first_name, ''), '') || ' ' || COALESCE(NULLIF(meta_last_name, ''), '')
  );

  IF meta_full_name = '' THEN
    meta_full_name := new.raw_user_meta_data->>'full_name';
  END IF;

  INSERT INTO public.users (id, role, full_name, first_name, last_name, contact, email)
  VALUES (
    new.id,
    CASE
      WHEN new.email = 'kabcal04@gmail.com' THEN 'admin'::user_role
      ELSE 'pending'::user_role
    END,
    meta_full_name,
    NULLIF(meta_first_name, ''),
    NULLIF(meta_last_name, ''),
    NULLIF(new.raw_user_meta_data->>'contact', ''),
    new.email
  );

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Migration to fix user trigger and ensure resilience
-- Group: Auth
-- Description: Updates handle_new_user trigger to be more robust and handle potential conflicts.

-- Ensure columns exist in case previous migrations were skipped or failed partially
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='full_name') THEN
        ALTER TABLE public.users ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email') THEN
        ALTER TABLE public.users ADD COLUMN email TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='first_name') THEN
        ALTER TABLE public.users ADD COLUMN first_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='last_name') THEN
        ALTER TABLE public.users ADD COLUMN last_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='contact') THEN
        ALTER TABLE public.users ADD COLUMN contact TEXT;
    END IF;
END $$;

-- Update the handle_new_user trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  meta_first_name TEXT;
  meta_last_name TEXT;
  meta_full_name TEXT;
  meta_contact TEXT;
BEGIN
  -- Extract metadata safely
  meta_first_name := COALESCE(new.raw_user_meta_data->>'first_name', '');
  meta_last_name := COALESCE(new.raw_user_meta_data->>'last_name', '');
  meta_contact := new.raw_user_meta_data->>'contact';
  
  -- Construct full name
  meta_full_name := trim(
    COALESCE(NULLIF(meta_first_name, ''), '') || ' ' || COALESCE(NULLIF(meta_last_name, ''), '')
  );

  -- Fallback for full_name if first/last are missing
  IF meta_full_name = '' THEN
    meta_full_name := COALESCE(new.raw_user_meta_data->>'full_name', '');
  END IF;

  -- Insert or Update to be resilient
  INSERT INTO public.users (id, role, full_name, first_name, last_name, contact, email)
  VALUES (
    new.id,
    CASE
      WHEN new.email = 'kabcal04@gmail.com' THEN 'admin'::user_role
      ELSE 'pending'::user_role
    END,
    NULLIF(meta_full_name, ''),
    NULLIF(meta_first_name, ''),
    NULLIF(meta_last_name, ''),
    NULLIF(meta_contact, ''),
    new.email
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name = EXCLUDED.full_name,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    contact = EXCLUDED.contact,
    email = EXCLUDED.email;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Restore handle_new_user trigger to a robust version
-- This migration ensures the trigger extracts all metadata and handles conflicts

-- Ensure columns exist in case previous migrations were skipped
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='full_name') THEN
        ALTER TABLE public.users ADD COLUMN full_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email') THEN
        ALTER TABLE public.users ADD COLUMN email TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='first_name') THEN
        ALTER TABLE public.users ADD COLUMN first_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='last_name') THEN
        ALTER TABLE public.users ADD COLUMN last_name TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='contact') THEN
        ALTER TABLE public.users ADD COLUMN contact TEXT;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  meta_first_name TEXT;
  meta_last_name TEXT;
  meta_full_name TEXT;
  meta_contact TEXT;
BEGIN
  -- Extract metadata safely
  meta_first_name := COALESCE(new.raw_user_meta_data->>'first_name', '');
  meta_last_name := COALESCE(new.raw_user_meta_data->>'last_name', '');
  meta_contact := new.raw_user_meta_data->>'contact';
  
  -- Construct full name
  meta_full_name := trim(
    COALESCE(NULLIF(meta_first_name, ''), '') || ' ' || COALESCE(NULLIF(meta_last_name, ''), '')
  );

  -- Fallback for full_name if first/last are missing
  IF meta_full_name = '' THEN
    meta_full_name := COALESCE(new.raw_user_meta_data->>'full_name', '');
  END IF;

  -- Insert or Update to be resilient
  INSERT INTO public.users (id, role, full_name, first_name, last_name, contact, email)
  VALUES (
    new.id,
    CASE
      WHEN new.email = 'kabcal04@gmail.com' THEN 'admin'::user_role
      ELSE 'pending'::user_role
    END,
    NULLIF(meta_full_name, ''),
    NULLIF(meta_first_name, ''),
    NULLIF(meta_last_name, ''),
    NULLIF(meta_contact, ''),
    new.email
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name = EXCLUDED.full_name,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    contact = EXCLUDED.contact,
    email = EXCLUDED.email;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
