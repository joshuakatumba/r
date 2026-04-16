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
