-- 03_triggers.sql
-- Trigger functions and triggers for Lennox project

-- Trigger Function for New User Onboarding
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  meta_first_name TEXT;
  meta_last_name TEXT;
  meta_full_name TEXT;
  meta_contact TEXT;
BEGIN
  -- Extract metadata safely from raw_user_meta_data
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

  -- Insert or Update (resilient to potential races)
  INSERT INTO public.users (id, role, full_name, first_name, last_name, contact, email)
  VALUES (
    new.id,
    CASE
      WHEN new.email = 'kabcal04@gmail.com' THEN 'admin'::public.user_role
      ELSE 'pending'::public.user_role
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

-- Trigger Definition
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
