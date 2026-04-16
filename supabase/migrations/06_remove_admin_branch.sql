-- Remove deprecated Admin Branch option from database
DO $$
DECLARE
  admin_branch_id UUID;
BEGIN
  SELECT id INTO admin_branch_id
  FROM public.branches
  WHERE name = 'Admin Branch'
  LIMIT 1;

  IF admin_branch_id IS NULL THEN
    RETURN;
  END IF;

  -- Detach users assigned to Admin Branch
  UPDATE public.users
  SET branch_id = NULL
  WHERE branch_id = admin_branch_id;

  -- Prevent orphaning transaction references
  IF EXISTS (
    SELECT 1
    FROM public.transactions
    WHERE branch_origin = admin_branch_id OR branch_claimed = admin_branch_id
  ) THEN
    RAISE EXCEPTION 'Cannot remove Admin Branch because it is referenced by transactions. Reassign those records first.';
  END IF;

  DELETE FROM public.branches
  WHERE id = admin_branch_id;
END
$$;
