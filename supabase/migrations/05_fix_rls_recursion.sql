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
