import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import { signout } from '@/app/actions/auth'
import LayoutNavigation from '@/components/LayoutNavigation'

export default async function AdminLayout({
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
    .select('role')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'admin') {
    redirect('/')
  }

  const navLinks = [
    { href: '/admin/dashboard', label: 'Dashboard', iconName: 'LayoutDashboard' },
    { href: '/admin/users', label: 'Users', iconName: 'Users' },
    { href: '/admin/transactions', label: 'Transactions', iconName: 'Banknote' },
    { href: '/admin/logs', label: 'Logs', iconName: 'ScrollText' },
  ]

  return (
    <div className="layout-wrapper">
      <LayoutNavigation 
        branchName="Admin Portal" 
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
