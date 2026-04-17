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
