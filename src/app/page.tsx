import { redirect } from 'next/navigation'
import { createClient } from '@/utils/supabase/server'
import { signout } from '@/app/actions/auth'

export default async function Home() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  const { data: profile } = await supabase
    .from('users')
    .select('role, branch_id')
    .eq('id', user.id)
    .single()

  // --- ACCESS CONTROL LOCKDOWN ---
  const appMode = process.env.NEXT_PUBLIC_APP_MODE // ADMIN or BRANCH
  const targetBranchId = process.env.NEXT_PUBLIC_BRANCH_ID

  if (profile?.role === 'admin') {
    // Admins can always access the Admin portal
    if (appMode === 'ADMIN') {
      redirect('/admin/dashboard')
    }
    // Optional: Allow admins to enter branch portals too
    if (appMode === 'BRANCH') {
      redirect('/branch/dashboard')
    }
  } else if (profile?.role === 'branch_user') {
    // Branch users MUST match the deployment's Branch ID
    if (appMode === 'BRANCH' && profile.branch_id === targetBranchId) {
      redirect('/branch/dashboard')
    } else {
      // Mismatch: Attempting to log into the wrong branch link
      redirect('/denied')
    }
  }

  // If role is pending or null
  return (
    <div className="center-page">
      <div className="card text-center animate-fade-in" style={{ maxWidth: '400px' }}>
        <h2 className="mb-2">Awaiting Approval</h2>
        <p className="mb-4">
          Your account is currently pending. Custom operations are restricted until an administrator assigns you a role and branch.
        </p>
        <form action={signout}>
          <button type="submit" className="btn btn-secondary btn-block">Sign Out</button>
        </form>
      </div>
    </div>
  )
}
