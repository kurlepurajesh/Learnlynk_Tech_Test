# LearnLynk Technical Assessment Submission

**Candidate Name:** [Your Name]  
**Submission Date:** 10 December 2025  
**Position:** Internship - Full Stack Developer  

---

## 📋 Overview

This repository contains my submission for the LearnLynk technical assessment. The project demonstrates a complete implementation of a multi-tenant admissions CRM backend with:

- ✅ Supabase database schema with proper relationships and constraints
- ✅ Row-Level Security (RLS) policies for multi-tenant data isolation
- ✅ Serverless Edge Function for task creation with real-time events
- ✅ Next.js dashboard page with React Query integration
- ✅ Stripe payment integration architecture

---

## 🗂️ Project Structure

```
learnlynk-tech-test/
├── backend/
│   ├── schema.sql              # Section 1: Database schema
│   ├── rls_policies.sql        # Section 2: Row-level security
│   └── supabase/
│       └── functions/
│           └── create-task/
│               └── index.ts    # Section 3: Edge Function
├── frontend/
│   └── app/
│       └── dashboard/
│           └── today/
│               └── page.tsx    # Section 4: Tasks dashboard
├── docs/
│   └── STRIPE_INTEGRATION.md   # Section 5: Stripe explanation
└── README.md
```

---

## 🚀 Running the Project

### Prerequisites
- Node.js 18+ and npm/yarn
- Supabase CLI (optional, for local development)
- PostgreSQL (if running locally)

### Setup Instructions

1. **Database Setup**
   ```bash
   # Run the schema in your Supabase project
   psql -h <your-db-host> -U postgres -d postgres -f backend/schema.sql
   
   # Apply RLS policies
   psql -h <your-db-host> -U postgres -d postgres -f backend/rls_policies.sql
   ```

2. **Edge Function Deployment**
   ```bash
   # Using Supabase CLI
   supabase functions deploy create-task
   ```

3. **Frontend Setup**
   ```bash
   cd frontend
   npm install
   
   # Create .env.local with:
   # NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   # NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
   
   npm run dev
   ```

---

## 📝 Key Design Decisions & Assumptions

### Section 1: Database Schema
- Added `title`, `description`, and `priority` fields to tasks for realistic CRM usage
- Used UUID v4 for all IDs via `gen_random_uuid()`
- Composite indexes for common query patterns (e.g., tenant + status)
- Soft delete support with `deleted_at` timestamp
- Added `email`, `phone`, `source` to leads table for complete contact management

### Section 2: RLS Policies
- Tenant isolation enforced at the database level for security
- Team-based access through `user_teams` junction table
- Admin role has full tenant-wide access
- Counselors see only their leads or team-shared leads
- INSERT policy ensures users can only create leads in their tenant

### Section 3: Edge Function
- **Missing from original spec:** Realtime broadcast implementation added
- Comprehensive input validation with detailed error messages
- Service role authentication for bypassing RLS
- CORS handling for cross-origin requests
- Proper HTTP status codes (400 for validation, 500 for server errors)

### Section 4: Frontend Dashboard
- Used React Query for caching and automatic refetching
- Optimistic UI updates when marking tasks complete
- Timezone-aware date filtering (UTC by default)
- Error boundary and loading states
- Responsive table design with TailwindCSS

### Section 5: Stripe Integration
- Webhook signature verification for security
- Idempotent payment processing to handle duplicate webhooks
- Transaction-based updates to prevent race conditions
- Audit trail with `payment_requests` table

---

## 🎯 What I Focused On

1. **Security First**
   - RLS policies prevent data leakage between tenants
   - Service role keys isolated to backend only
   - Input validation on all user-provided data

2. **Production Ready**
   - Proper error handling and logging
   - Database indexes for performance
   - Idempotent operations (webhooks, edge functions)

3. **Developer Experience**
   - Clear code organization and naming conventions
   - Comprehensive comments in complex logic
   - Type safety with TypeScript throughout

4. **Scalability**
   - Multi-tenant architecture from day one
   - Indexed queries for common access patterns
   - Edge functions for serverless scalability

---

## 🔍 Testing Recommendations

### Database
```sql
-- Test lead access (as counselor)
SELECT * FROM leads WHERE tenant_id = 'test-tenant-id';

-- Test task constraints
INSERT INTO tasks (task_type, due_at) 
VALUES ('invalid', NOW() - INTERVAL '1 day'); -- Should fail
```

### Edge Function
```bash
curl -X POST https://your-project.supabase.co/functions/v1/create-task \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "application_id": "123e4567-e89b-12d3-a456-426614174000",
    "task_type": "call",
    "due_at": "2025-12-15T10:00:00Z",
    "tenant_id": "tenant-123"
  }'
```

### Frontend
- Navigate to `/dashboard/today`
- Verify tasks due today appear
- Click "Mark Complete" and confirm UI updates
- Check network tab for proper API calls

---

## 📚 Additional Notes

- All timestamps use `TIMESTAMPTZ` for timezone awareness
- Foreign keys use `ON DELETE CASCADE` for referential integrity
- The schema supports soft deletes (nullable `deleted_at` field)
- Real-time subscriptions can be added for live task updates
- The Edge Function can be extended to send notifications (email/SMS)

---

## 🤝 Contact

For any questions or clarifications:

**Email:** [your-email@example.com]  
**GitHub:** [your-github-username]  
**LinkedIn:** [your-linkedin-profile]

---

Thank you for the opportunity to work on this assessment. I look forward to discussing the implementation in detail!
