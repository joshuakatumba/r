import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import { signout } from '@/app/actions/auth'
import LayoutNavigation from '@/components/LayoutNavigation'

export default async function BranchLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  const { data: profile } = await supabase
    .from('users')
    .select('role, branch_id, branches(name)')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'branch_user') {
    redirect('/')
  }

  const branchName = (profile.branches as any)?.name || "Sudan Branch"

  const navLinks = [
    { href: '/sudan/dashboard', label: 'Dashboard', iconName: 'LayoutDashboard' },
    { href: '/sudan/create', label: 'Send Money', iconName: 'SendHorizontal' },
    { href: '/sudan/claim', label: 'Receive Money', iconName: 'Download' },
    { href: '/sudan/history', label: 'History', iconName: 'History' },
  ]

  return (
    <div className="layout-wrapper">
      <LayoutNavigation 
        branchName={branchName} 
        links={navLinks} 
        signoutAction={signout} 
      />

      <main className="main-content flex-1 animate-fade-in">
        <div className="container">
          {children}
        </div>
      </main>
    </div>
  )
}
