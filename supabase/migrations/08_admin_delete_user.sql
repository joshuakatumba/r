-- 08_admin_delete_user.sql
-- Function to safely delete a user, bypassing RLS cascade issues

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user_id UUID)
RETURNS void AS $$
BEGIN
    -- Verify the caller is an admin
    IF (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Admin only';
    END IF;

    -- Delete the user profile
    -- The cascading ON DELETE SET NULL constraints will also execute under this SECURITY DEFINER context, bypassing RLS.
    DELETE FROM public.users WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
