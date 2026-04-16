import Link from 'next/link'
import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import { signout } from '@/app/actions/auth'
import { LayoutDashboard, Users, Banknote, ScrollText, LogOut } from 'lucide-react'

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

  return (
    <div className="layout-wrapper">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="sidebar-brand">
            <div style={{ width: '32px', height: '32px', background: 'var(--accent-primary)', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: 'white' }}>A</div>
            Admin
          </div>
        </div>

        <nav className="sidebar-nav">
          <Link href="/admin/dashboard" className="sidebar-link">
            <LayoutDashboard size={18} /> Dashboard
          </Link>
          <Link href="/admin/users" className="sidebar-link">
            <Users size={18} /> Users
          </Link>
          <Link href="/admin/transactions" className="sidebar-link">
            <Banknote size={18} /> Transactions
          </Link>
          <Link href="/admin/logs" className="sidebar-link">
            <ScrollText size={18} /> Logs
          </Link>
        </nav>

        <div className="sidebar-footer">
          <div className="portal-badge">
            <span></span> Admin Portal
          </div>
          <form action={signout}>
            <button type="submit" className="btn btn-secondary btn-block" style={{ fontSize: '0.85rem', display: 'flex', gap: '8px' }}>
              <LogOut size={16} /> Sign Out
            </button>
          </form>
        </div>
      </aside>

      <main className="main-content flex-1 animate-fade-in">
        <div className="container">
          {children}
        </div>
      </main>
    </div>
  )
}
