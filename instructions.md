Got you — no extra talk, straight to what you asked.

---

# 🔁 1. FULL WORKFLOW (CLEAR + COMPLETE)

### 🔐 AUTH FLOW

```text
User signs up → role = PENDING
        ↓
Admin reviews request
        ↓
Approve → assign (ADMIN or BRANCH_USER + branch)
Reject → user blocked
```

---

### 💰 CREATE TRANSACTION (South Sudan or Uganda)

```text
Customer gives money
        ↓
Branch user enters amount
        ↓
System generates UNIQUE CODE
        ↓
Transaction saved:
  - status = PENDING
  - branch_origin = current branch
        ↓
Code given to customer
```

---

### 🌍 CLAIM TRANSACTION (Other Branch)

```text
Customer provides code
        ↓
Branch user enters code
        ↓
System checks:
   - Exists?
   - status = PENDING?
   - Not expired?
        ↓
IF VALID:
   → Release money
   → status = CLAIMED
   → save claimed_by + branch_claimed

IF INVALID:
   → Reject
```

---

### 🧠 ADMIN FLOW

```text
Admin logs in
        ↓
Views:
   - All transactions
   - Pending vs Claimed
   - Logs
   - Users
        ↓
Actions:
   - Approve users
   - Monitor branches
   - Audit system
```

---

# 🧱 2. SYSTEM FLOW (ONE LINE VIEW)

```text
Register Money → Generate Code → Store (PENDING) → Move → Verify Code → Claim → Update (CLAIMED)
```

---

# ⚙️ 3. ANTI-GRAVITY INITIALIZATION PROMPT

Copy this exactly — no edits needed:

---

Initialize a full-stack POS and cross-border transaction tracking system using Supabase for database and authentication.

PROJECT SETUP:

* Frontend: React or Next.js
* Backend: Node.js API (or Next.js API routes)
* Database/Auth: Supabase (PostgreSQL + Auth)

ROLES:

* admin
* branch_user
* pending (default after signup)

BRANCHES:

* Uganda
* South Sudan

CORE FEATURES:

1. AUTHENTICATION:

* Use Supabase Auth (email/password)
* On signup → assign role = "pending"
* Admin approves users and assigns:

  * role (admin or branch_user)
  * branch (Uganda or South Sudan)

2. TRANSACTION CREATION:

* Branch user inputs amount
* Generate unique secure code (UUID + branch prefix)
* Save transaction:

  * code (unique)
  * amount
  * status = PENDING
  * branch_origin
  * created_by
  * created_at

3. TRANSACTION CLAIM:

* Input: code
* Validate:

  * exists
  * status = PENDING
* If valid:

  * update status = CLAIMED
  * set claimed_by
  * set branch_claimed
  * set claimed_at
* If invalid → return error

4. DATABASE TABLES:

users:

* id (from auth)
* role (admin, branch_user, pending)
* branch_id

branches:

* id
* name

transactions:

* id
* code (unique)
* amount
* status (PENDING, CLAIMED)
* branch_origin
* branch_claimed
* created_by
* claimed_by
* created_at
* claimed_at

logs:

* id
* user_id
* action
* details
* created_at

5. ACCESS RULES:

* Admin:

  * full access
  * approve users
  * view all transactions and logs
* Branch user:

  * create transactions
  * claim transactions
  * view only their branch data

6. API ENDPOINTS:

POST /transactions/create
POST /transactions/claim
GET /transactions
GET /admin/users
POST /admin/approve
GET /admin/logs

7. UI PAGES:

Admin:

* dashboard
* user management
* transactions
* logs

Branch user:

* dashboard
* create transaction
* claim transaction
* history

8. SYSTEM RULES:

* Codes must be unique
* Transactions can only be claimed once
* All actions must be logged
* Enforce role-based access control

GOAL:
Generate a clean, production-ready MVP with proper folder structure, Supabase integration, and working authentication + transaction flow.


