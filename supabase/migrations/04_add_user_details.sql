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
