# Cross Border Internal Transfer System

A web-based platform built for managing cross-border money transfers between regional branch offices. It enables branch operators to initiate transfers at one location and have them claimed at another, with a centralized admin panel for oversight.


## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Database Schema](#database-schema)
- [User Roles and Access Control](#user-roles-and-access-control)
- [Core Workflows](#core-workflows)
- [Project Structure](#project-structure)
- [Environment Variables](#environment-variables)
- [Getting Started](#getting-started)
- [Database Setup](#database-setup)
- [Deployment](#deployment)


## Overview

Cross Border Internal Transfer System solves a specific problem: facilitating money transfers between two geographically separate branches (Uganda and Sudan). A customer walks into one branch, deposits money, and receives a unique transfer code printed on a receipt. At the destination branch, a different operator enters that code to release the funds to the recipient.

The system tracks every transaction, logs every user action, and notifies relevant parties in real time.


## Architecture

The application follows a three-portal architecture:

```
                    +-------------------+
                    |   Supabase Cloud  |
                    | (Auth + Postgres) |
                    +--------+----------+
                             |
              +--------------+--------------+
              |              |              |
     +--------+---+  +------+------+  +----+--------+
     | Uganda     |  | Sudan       |  | Admin       |
     | Branch     |  | Branch      |  | Portal      |
     | Portal     |  | Portal      |  |             |
     +------------+  +-------------+  +-------------+
```

Branch Portals (Uganda and Sudan) are used by frontline branch operators to send and receive money.
Admin Portal is used by system administrators to manage users, monitor transactions, and review audit logs.
Supabase provides authentication, the PostgreSQL database, and real-time event broadcasting.

All three portals share the same database but are separated into their own Next.js applications, each with its own layout, theme, and access restrictions.


## Technology Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| Framework    | Next.js (App Router)                |
| Language     | TypeScript                          |
| UI           | React, Vanilla CSS, Lucide Icons    |
| Font         | Inter (Google Fonts)                |
| Auth         | Supabase Auth (email/password)      |
| Database     | PostgreSQL via Supabase             |
| Real-time    | Supabase Realtime (notifications)   |
| Deployment   | Node.js (npm run build && npm start)|


## Database Schema

The database consists of five tables:

### branches

Stores the branch offices that operate within the system.

| Column     | Type        | Description                  |
|------------|-------------|------------------------------|
| id         | UUID (PK)   | Auto-generated identifier    |
| name       | TEXT UNIQUE | Branch display name          |
| created_at | TIMESTAMPTZ | Record creation timestamp    |

Seeded with two rows: Uganda Branch and Sudan Branch.

### users

Stores user profiles, linked to Supabase Auth via the id column.

| Column     | Type        | Description                          |
|------------|-------------|--------------------------------------|
| id         | UUID (PK)   | References auth.users(id)            |
| role       | ENUM        | admin, branch_user, or pending       |
| branch_id  | UUID (FK)   | References branches(id), nullable    |
| full_name  | TEXT        | Constructed from first + last name   |
| first_name | TEXT        | User first name                      |
| last_name  | TEXT        | User last name                       |
| contact    | TEXT        | Phone number                         |
| email      | TEXT        | Email address                        |
| created_at | TIMESTAMPTZ | Record creation timestamp            |

A database trigger (handle_new_user) automatically creates a row in this table whenever a new user registers through Supabase Auth. The trigger extracts the user metadata from the auth payload and inserts a profile with role pending.

### transactions

Stores every money transfer initiated in the system.

| Column         | Type        | Description                                  |
|----------------|-------------|----------------------------------------------|
| id             | UUID (PK)   | Auto-generated identifier                    |
| code           | TEXT UNIQUE | Human-readable transfer code (e.g., UG-5BMWZ750) |
| amount         | NUMERIC     | Transfer amount                              |
| sender_name    | TEXT        | Name of the person depositing money          |
| sender_contact | TEXT        | Sender phone number                          |
| sender_address | TEXT        | Sender physical address                      |
| status         | ENUM        | PENDING or CLAIMED                           |
| branch_origin  | UUID (FK)   | Branch where the transfer was initiated      |
| branch_claimed | UUID (FK)   | Branch where the transfer was claimed        |
| created_by     | UUID (FK)   | User who created the transaction             |
| claimed_by     | UUID (FK)   | User who claimed the transaction             |
| created_at     | TIMESTAMPTZ | When the transfer was initiated              |
| claimed_at     | TIMESTAMPTZ | When the transfer was claimed                |

### logs

Stores an audit trail of every significant action in the system.

| Column     | Type        | Description                          |
|------------|-------------|--------------------------------------|
| id         | UUID (PK)   | Auto-generated identifier            |
| user_id    | UUID (FK)   | The user who performed the action    |
| action     | TEXT        | Action type                          |
| details    | JSONB       | Structured metadata about the action |
| created_at | TIMESTAMPTZ | When the action occurred             |

### notifications

Stores in-app notifications delivered to users.

| Column     | Type        | Description                                |
|------------|-------------|-------------------------------------------|
| id         | UUID (PK)   | Auto-generated identifier                  |
| user_id    | UUID (FK)   | The recipient of the notification          |
| type       | TEXT        | Notification category                      |
| title      | TEXT        | Short heading                              |
| message    | TEXT        | Notification body text                     |
| metadata   | JSONB       | Additional structured data                 |
| is_read    | BOOLEAN     | Whether the user has seen it               |
| created_at | TIMESTAMPTZ | When the notification was generated        |

Notifications are generated automatically by database triggers when a new user signs up, when a user role is updated, when a transaction is created and when a transaction is claimed.


## User Roles and Access Control

The system enforces three distinct roles:

### pending

Every new user starts with this role. They cannot access any portal. An admin must promote them to branch_user and assign them to a branch before they can use the system.

### branch_user

Frontline operators at a branch office. They can initiate money transfers, claim incoming transfers using a transfer code, view their branch transaction history, view their dashboard with summary statistics and receive real-time notifications.

Branch users are restricted to their assigned branch portal. A user assigned to the Uganda branch accesses only the Uganda portal.

### admin

System administrators who manage the entire platform. They can view and manage all registered users, promote or demote user roles, assign users to branches, delete user accounts, view all transactions across all branches, review the complete audit log and receive notifications about new signups and transactions.


## Core Workflows

### 1. User Registration and Activation

```
Customer registers via /signup
         |
         v
Supabase Auth creates auth.users row
         |
         v
Database trigger creates public.users row (role = 'pending')
         |
         v
Notification trigger alerts all admins
         |
         v
Admin opens /admin/users, sets role to 'branch_user', assigns a branch
         |
         v
User can now log in and access their branch portal
```

### 2. Sending Money (Creating a Transaction)

```
Branch operator at Branch A navigates to /create
         |
         v
Fills in sender name, contact, address, and amount
         |
         v
Server action generates a unique transfer code
         |
         v
Transaction row inserted with status = 'PENDING'
         |
         v
Action logged to the logs table
         |
         v
Notification sent to the creator and all admins
         |
         v
Receipt displayed on screen with QR code and transfer code
         |
         v
Operator prints receipt for the customer
```

### 3. Receiving Money (Claiming a Transaction)

```
Branch operator at Branch B navigates to /claim
         |
         v
Enters the transfer code provided by the customer
         |
         v
Server action validates the code exists, status is PENDING and claiming branch differs from origin branch
         |
         v
Transaction preview displayed (amount, sender, origin branch)
         |
         v
Operator confirms the claim
         |
         v
Transaction updated: status = 'CLAIMED', claimed_at = now
         |
         v
Action logged, notification sent to the original creator
```

### 4. Admin User Management

```
Admin navigates to /admin/users
         |
         v
Sees a table of all users with name, email, role, and branch
         |
         v
Clicks a user name to open their profile modal
         |
         v
Can change role and assign a branch or delete the account
         |
         v
Every action is logged with the admin's user ID and the target user details
```


## Environment Variables

The environment files are included in the repository. Each system (admin, uganda, sudan) has its own .env file with the Supabase project URL and service role key already configured.


## Getting Started

### Prerequisites

Node.js 18 or later and npm.

### Installation

```bash
git clone https://github.com/joshuakatumba/Transaction-Tracking-System.git
cd Transaction-Tracking-System
```

### Run Each Portal

```bash
cd admin-system && npm install && npm run dev
cd uganda-system && npm install && npm run dev
cd sudan-system && npm install && npm run dev
```

Admin portal runs on http://localhost:3000
Uganda portal runs on http://localhost:3001
Sudan portal runs on http://localhost:3002


## Database Setup

Run the migration files in order against your Supabase project through the Supabase SQL Editor.

1. 01_init.sql creates the core tables (branches, users, transactions, logs)
2. 02_security.sql enables Row-Level Security and creates access policies
3. 03_triggers.sql creates the user onboarding trigger
4. 04_seed.sql inserts the two branch records
5. 05_permissions.sql grants necessary table permissions
6. 06_notifications.sql creates the notifications table and all notification triggers


## Deployment

```bash
npm run build
npm start
```

The application requires a stable connection to Supabase. The notification system uses Supabase Realtime so ensure the notifications table is added to the supabase_realtime publication if real-time alerts are not appearing. Receipts include a dynamically generated QR code via the qrserver.com API so an active internet connection is required for QR codes to render on printed receipts.
