import Link from 'next/link'
import { createClient } from '@/utils/supabase/server'
import { redirect } from 'next/navigation'
import { signout } from '@/app/actions/auth'
import { LayoutDashboard, SendHorizontal, Download, History, LogOut } from 'lucide-react'

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
    .select('role, branches (name)')
    .eq('id', user.id)
    .single()

  if (profile?.role !== 'branch_user') {
    redirect('/')
  }

  const branchName = (profile.branches as { name: string }[] | null)?.[0]?.name || 'Unknown Branch'

  const branchDisplayName = process.env.NEXT_PUBLIC_BRANCH_NAME || branchName

  return (
    <div className="layout-wrapper">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="sidebar-brand">
            <div style={{ width: '32px', height: '32px', background: 'var(--accent-primary)', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: 'white' }}>B</div>
            {branchDisplayName}
          </div>
        </div>

        <nav className="sidebar-nav">
          <Link href="/branch/dashboard" className="sidebar-link">
            <LayoutDashboard size={18} /> Dashboard
          </Link>
          <Link href="/branch/create" className="sidebar-link">
            <SendHorizontal size={18} /> Send Money
          </Link>
          <Link href="/branch/claim" className="sidebar-link">
            <Download size={18} /> Receive Money
          </Link>
          <Link href="/branch/history" className="sidebar-link">
            <History size={18} /> History
          </Link>
        </nav>

        <div className="sidebar-footer">
          <div className="portal-badge">
            <span></span> Branch Portal
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
