-- Backfill migration for existing projects created before sender fields were added.
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS sender_name TEXT,
  ADD COLUMN IF NOT EXISTS sender_contact TEXT,
  ADD COLUMN IF NOT EXISTS sender_address TEXT;
