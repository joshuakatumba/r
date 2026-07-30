-- 04_seed.sql
-- Initial data seeding for Lennox project

-- 1. Insert Branches
INSERT INTO public.branches (name) 
VALUES ('Uganda Branch'), ('Sudan Branch')
ON CONFLICT (name) DO NOTHING;

-- 2. Seed Admin Account into auth.users (if not already existing)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  new_admin_id UUID := gen_random_uuid();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin123@gmail.com') THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role,
      aud
    )
    VALUES (
      new_admin_id,
      '00000000-0000-0000-0000-000000000000',
      'admin123@gmail.com',
      crypt('12345678', gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      '{"full_name": "System Admin", "first_name": "System", "last_name": "Admin"}'::jsonb,
      now(),
      now(),
      'authenticated',
      'authenticated'
    );
  END IF;

  -- Ensure user profile is set to admin role
  UPDATE public.users
  SET role = 'admin', full_name = 'System Admin'
  WHERE email = 'admin123@gmail.com';
END $$;
