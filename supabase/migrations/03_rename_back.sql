-- Rename branches back to specific names
BEGIN;

UPDATE public.branches 
SET name = 'Uganda Branch' 
WHERE name = 'Branch A';

UPDATE public.branches 
SET name = 'Sudan Branch' 
WHERE name = 'Branch B';

COMMIT;
