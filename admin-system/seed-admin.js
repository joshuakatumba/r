const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in your environment.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function seedAdmin() {
  console.log("Forcing creation of admin user (bypassing email checks)...");
  
  const email = 'admin123@gmail.com';
  const password = '12345678';
  
  const { data: authData, error: authError } = await supabase.auth.admin.createUser({
    email: email,
    password: password,
    email_confirm: true,
    user_metadata: {
      full_name: "System Admin",
      first_name: "System",
      last_name: "Admin"
    }
  });

  let userId = null;

  if (authError) {
    if (authError.message.includes('already')) {
      console.log(`User ${email} already exists in Auth. Fetching ID...`);
      // Get the existing user ID
      const { data: usersData, error: listError } = await supabase.auth.admin.listUsers();
      const existingUser = usersData?.users.find(u => u.email === email);
      if (existingUser) {
        userId = existingUser.id;
      }
    } else {
      console.error("Error creating user:", authError.message);
      return;
    }
  } else {
    console.log(`Successfully created ${email}.`);
    userId = authData?.user?.id;
  }

  if (!userId) {
    console.error("Could not find User ID to assign admin role.");
    return;
  }

  console.log(`Assigning admin role to user ID: ${userId}...`);
  // Use upsert so it creates the profile if the trigger didn't run
  const { data: updateData, error: updateError } = await supabase
    .from('users')
    .upsert({ 
      id: userId, 
      email: email, 
      role: 'admin', 
      full_name: 'System Admin' 
    });

  if (updateError) {
    console.error("Error setting admin role:", updateError.message);
  } else {
    console.log("Successfully granted Admin permissions! You can now log in.");
  }
}

seedAdmin();
