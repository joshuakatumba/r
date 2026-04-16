-- Rename existing branches to match the new naming convention
BEGIN;

UPDATE public.branches 
SET name = 'Branch A' 
WHERE name = 'Uganda';

UPDATE public.branches 
SET name = 'Branch B' 
WHERE name = 'South Sudan';

COMMIT;
