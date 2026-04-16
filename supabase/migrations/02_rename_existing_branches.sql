-- Rename existing branches to match the new naming convention
BEGIN;

UPDATE public.branches 
SET name = 'Branch A' 
WHERE name = 'Uganda';

UPDATE public.branches 
SET name = 'Branch B' 
WHERE name = 'South Sudan';

-- Ensure "Admin Branch" exists
INSERT INTO public.branches (name) 
VALUES ('Admin Branch') 
ON CONFLICT (name) DO NOTHING;

COMMIT;
