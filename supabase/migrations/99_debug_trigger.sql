-- Temporary debug migration to see trigger values
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'DEBUG_VALS: email=[%], id=[%], meta=[%]', new.email, new.id, new.raw_user_meta_data;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
