'use client'

import { useState, useEffect } from 'react'
import { Menu, X, LogOut, LayoutDashboard, SendHorizontal, Download, History, Users, Banknote, ScrollText } from 'lucide-react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import NotificationBell from './NotificationBell'

// Map string names to icon components — avoids passing JSX from Server to Client
const iconMap: Record<string, React.ComponentType<{ size: number }>> = {
  LayoutDashboard,
  SendHorizontal,
  Download,
  History,
  Users,
  Banknote,
  ScrollText,
}

interface NavLink {
  href: string
  label: string
  iconName: string // pass a string key, not JSX
}

interface SidebarProps {
  branchName: string
  links: NavLink[]
  signoutAction: () => void
}

export default function LayoutNavigation({ branchName, links, signoutAction }: SidebarProps) {
  const [isOpen, setIsOpen] = useState(false)
  const pathname = usePathname()

  // Close sidebar on route change
  useEffect(() => {
    setIsOpen(false)
  }, [pathname])

  // Lock body scroll when sidebar is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  return (
    <>
      {/* Mobile Header */}
      <header className="mobile-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ 
            width: 32, height: 32, 
            background: 'var(--accent-primary)', borderRadius: 6, 
            display: 'flex', alignItems: 'center', justifyContent: 'center', 
            fontWeight: 'bold', color: 'white', fontSize: '0.85rem'
          }}>
            {branchName.charAt(0)}
          </div>
          <span style={{ fontWeight: 700 }}>{branchName}</span>
        </div>
        <button 
          onClick={() => setIsOpen(true)} 
          aria-label="Open menu"
          style={{ 
            background: 'rgba(255,255,255,0.1)', border: 'none', color: 'white', 
            padding: 10, borderRadius: 8, display: 'flex', alignItems: 'center',
            cursor: 'pointer'
          }}
        >
          <Menu size={22} />
        </button>
      </header>

      {/* Overlay */}
      {isOpen && (
        <div 
          onClick={() => setIsOpen(false)}
          style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            background: 'rgba(15, 23, 42, 0.6)',
            backdropFilter: 'blur(4px)',
            zIndex: 15000,
          }}
        />
      )}

      {/* Sidebar */}
      <aside 
        className="sidebar"
        style={{
          // On mobile these inline styles will override the CSS to control open/close
          // On desktop the CSS handles everything normally
        }}
      >
        {/* Close button — only visible on mobile */}
        <div className="sidebar-close-row">
          <button 
            onClick={() => setIsOpen(false)} 
            aria-label="Close menu"
            className="sidebar-close-btn"
          >
            <X size={20} />
          </button>
        </div>

        <div className="sidebar-header">
          <div className="sidebar-brand">
            <div style={{ 
              width: 32, height: 32, 
              background: 'var(--accent-primary)', borderRadius: 6, 
              display: 'flex', alignItems: 'center', justifyContent: 'center', 
              fontWeight: 'bold', color: 'white', fontSize: '0.85rem'
            }}>
              {branchName.charAt(0)}
            </div>
            {branchName}
          </div>
        </div>

        <nav className="sidebar-nav">
          {links.map((link) => {
            const IconComponent = iconMap[link.iconName]
            const isActive = pathname === link.href || pathname.startsWith(link.href + '/')
            return (
              <Link 
                key={link.href} 
                href={link.href} 
                className={isActive ? 'active' : ''}
                onClick={() => setIsOpen(false)}
              >
                {IconComponent && <IconComponent size={18} />} {link.label}
              </Link>
            )
          })}
        </nav>

        <div className="sidebar-footer">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
            <div className="portal-badge">
              <span></span> Portal
            </div>
            <NotificationBell />
          </div>
          <form action={signoutAction}>
            <button 
              type="submit" 
              className="btn btn-secondary btn-block" 
              style={{ 
                fontSize: '0.85rem', display: 'flex', alignItems: 'center',
                justifyContent: 'center', gap: 8, width: '100%'
              }}
            >
              <LogOut size={16} /> Sign Out
            </button>
          </form>
        </div>
      </aside>
    </>
  )
}
