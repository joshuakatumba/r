-- 01_init.sql
-- Initial schema setup for Lennox project

-- 0. Cleanup existing objects
DROP TABLE IF EXISTS public.logs CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.branches CASCADE;

DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.transaction_status CASCADE;

-- 1. Create Enums
CREATE TYPE public.user_role AS ENUM ('admin', 'branch_user', 'pending');
CREATE TYPE public.transaction_status AS ENUM ('PENDING', 'CLAIMED');

-- 2. Create Tables
CREATE TABLE public.branches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    role public.user_role DEFAULT 'pending'::public.user_role NOT NULL,
    branch_id UUID REFERENCES public.branches(id),
    full_name TEXT,
    first_name TEXT,
    last_name TEXT,
    contact TEXT,
    email TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    amount NUMERIC NOT NULL,
    sender_name TEXT,
    sender_contact TEXT,
    sender_address TEXT,
    status public.transaction_status DEFAULT 'PENDING'::public.transaction_status NOT NULL,
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
