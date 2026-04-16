-- Add missing sender detail columns to transactions table
ALTER TABLE public.transactions 
ADD COLUMN sender_name TEXT,
ADD COLUMN sender_contact TEXT,
ADD COLUMN sender_address TEXT;
