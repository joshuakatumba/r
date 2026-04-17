const { createClient } = require('@supabase/supabase-js')

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase env vars')
  process.exit(1)
}

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testSignup() {
  const email = `test_${Date.now()}@example.com`
  const password = 'Password123!'
  
  console.log('Testing signup for:', email)
  
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        first_name: 'Test',
        last_name: 'User',
        full_name: 'Test User',
        contact: '+256700000000',
      },
    },
  })
  
  if (error) {
    console.error('Signup failed:', error)
  } else {
    console.log('Signup succeeded:', data.user.id)
    
    // Check if profile was created in public.users
    const { data: profile, error: profileError } = await supabase
      .from('users')
      .select('*')
      .eq('id', data.user.id)
      .single()
      
    if (profileError) {
      console.error('Profile check failed:', profileError)
    } else {
      console.log('Profile created successfully:', profile)
    }
  }
}

testSignup()
