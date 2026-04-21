-- 07_fix_user_deletion.sql
-- Fix user deletion by allowing NULL on foreign keys and adding ON DELETE SET NULL

-- 1. Update transactions table
-- First, make created_by nullable
ALTER TABLE public.transactions ALTER COLUMN created_by DROP NOT NULL;

-- Drop and recreate foreign keys for transactions
ALTER TABLE public.transactions 
DROP CONSTRAINT IF EXISTS transactions_created_by_fkey,
DROP CONSTRAINT IF EXISTS transactions_claimed_by_fkey;

ALTER TABLE public.transactions
ADD CONSTRAINT transactions_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL,
ADD CONSTRAINT transactions_claimed_by_fkey 
    FOREIGN KEY (claimed_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- 2. Update logs table
ALTER TABLE public.logs 
DROP CONSTRAINT IF EXISTS logs_user_id_fkey;

ALTER TABLE public.logs
ADD CONSTRAINT logs_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;
