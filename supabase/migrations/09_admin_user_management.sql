-- 09_admin_user_management.sql
-- High-privilege functions for administrators to manage users

-- Function to completely delete a user (including auth.users)
CREATE OR REPLACE FUNCTION public.admin_delete_user_full(target_user_id UUID)
RETURNS void AS $$
BEGIN
    -- Verify the caller is an admin
    IF (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Admin only';
    END IF;

    -- Delete from auth.users (this cascades to public.users)
    -- Must be executed by a user with privileges on auth schema (postgres)
    DELETE FROM auth.users WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Function to forcefully update a user's role and branch
CREATE OR REPLACE FUNCTION public.admin_update_user(
    target_user_id UUID,
    new_role public.user_role,
    new_branch_id UUID
)
RETURNS void AS $$
BEGIN
    -- Verify the caller is an admin
    IF (SELECT role FROM public.users WHERE id = auth.uid()) != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Admin only';
    END IF;

    -- Update the user profile
    UPDATE public.users 
    SET role = new_role, branch_id = new_branch_id 
    WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
