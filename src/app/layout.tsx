import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: process.env.NEXT_PUBLIC_BRANCH_NAME || 'POS',
  description: 'Secure cross-border transaction tracking system',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const branchName = process.env.NEXT_PUBLIC_BRANCH_NAME || ''
  
  let themeClass = ''
  if (branchName.toLowerCase().includes('admin')) {
    themeClass = 'theme-admin'
  } else if (branchName.toLowerCase().includes('uganda')) {
    themeClass = 'theme-uganda'
  } else if (branchName.toLowerCase().includes('sudan')) {
    themeClass = 'theme-sudan'
  }

  return (
    <html lang="en">
      <body className={themeClass}>
        {children}
      </body>
    </html>
  )
}
