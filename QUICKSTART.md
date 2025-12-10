# Quick Start Guide

Get the LearnLynk CRM technical assessment running in under 10 minutes.

---

## Prerequisites

- [Node.js 18+](https://nodejs.org/)
- [Supabase Account](https://supabase.com) (free tier works)
- [Supabase CLI](https://supabase.com/docs/guides/cli) (optional but recommended)
- Git

---

## 🚀 Step 1: Clone or Download

```bash
# If you have the zip file
unzip learnlynk-tech-test.zip
cd learnlynk-tech-test

# Or from GitHub
git clone <your-repo-url>
cd learnlynk-tech-test
```

---

## 🗄️ Step 2: Setup Database

### Option A: Using Supabase Dashboard (Easiest)

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Wait for the project to finish setup (~2 minutes)
3. Navigate to **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy and paste contents of `backend/schema.sql`
6. Click **Run** or press `Ctrl/Cmd + Enter`
7. Create another new query
8. Copy and paste contents of `backend/rls_policies.sql`
9. Click **Run**

### Option B: Using psql (Advanced)

```bash
# Get connection string from Supabase Dashboard > Settings > Database
psql "postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT].supabase.co:5432/postgres"

# Run schema
\i backend/schema.sql

# Run RLS policies
\i backend/rls_policies.sql

# Verify
\dt
```

---

## ⚡ Step 3: Deploy Edge Function

### Option A: Using Supabase CLI (Recommended)

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Deploy the function
supabase functions deploy create-task
```

### Option B: Manual Deployment

1. Go to **Edge Functions** in Supabase Dashboard
2. Click **Create Function**
3. Name it: `create-task`
4. Copy contents of `backend/supabase/functions/create-task/index.ts`
5. Paste and deploy

---

## 🎨 Step 4: Setup Frontend

```bash
cd frontend

# Install dependencies
npm install

# Create environment file
cat > .env.local << EOF
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
EOF

# Get your values from:
# Supabase Dashboard > Settings > API
# - Project URL
# - anon/public key

# Start development server
npm run dev
```

Open [http://localhost:3000/dashboard/today](http://localhost:3000/dashboard/today)

---

## 🧪 Step 5: Test with Sample Data

### Insert Test Data

Run this in Supabase SQL Editor:

```sql
-- Create a test tenant UUID (save this for later)
SELECT gen_random_uuid() as tenant_id;

-- Insert a test lead (replace tenant_id with the UUID above)
INSERT INTO leads (tenant_id, first_name, last_name, email, stage, owner_id)
VALUES 
  ('YOUR_TENANT_ID_HERE', 'John', 'Doe', 'john@example.com', 'new', gen_random_uuid())
RETURNING *;

-- Create an application (replace tenant_id and use the lead id from above)
INSERT INTO applications (tenant_id, lead_id, program, status)
VALUES 
  ('YOUR_TENANT_ID_HERE', 
   (SELECT id FROM leads WHERE email = 'john@example.com'), 
   'MBA', 'draft')
RETURNING *;

-- Create a task due today (replace tenant_id and use application id)
INSERT INTO tasks (tenant_id, application_id, title, type, due_at, priority)
VALUES 
  ('YOUR_TENANT_ID_HERE',
   (SELECT id FROM applications LIMIT 1),
   'Follow up with applicant',
   'call',
   NOW() + INTERVAL '2 hours',
   'high')
RETURNING *;
```

### Verify Frontend

Refresh `http://localhost:3000/dashboard/today` and you should see your task!

---

## 🎯 Step 6: Test the Edge Function

```bash
# Replace with your Supabase URL and anon key
curl -X POST https://your-project.supabase.co/functions/v1/create-task \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "application_id": "YOUR_APPLICATION_ID",
    "task_type": "email",
    "due_at": "2025-12-15T14:00:00Z",
    "tenant_id": "YOUR_TENANT_ID",
    "title": "Send acceptance letter",
    "priority": "high"
  }'
```

Expected response:
```json
{
  "success": true,
  "task_id": "some-uuid"
}
```

---

## 📋 Common Issues & Solutions

### Issue: Frontend shows "Failed to fetch tasks"

**Solution**: Check your `.env.local` file has correct values from Supabase Dashboard > Settings > API

### Issue: RLS policies blocking queries

**Solution**: For testing, temporarily disable RLS:
```sql
ALTER TABLE leads DISABLE ROW LEVEL SECURITY;
ALTER TABLE applications DISABLE ROW LEVEL SECURITY;
ALTER TABLE tasks DISABLE ROW LEVEL SECURITY;
```

### Issue: Edge Function returns 500 error

**Solution**: Check function logs:
```bash
supabase functions logs create-task --tail
```

### Issue: "relation does not exist" error

**Solution**: Make sure you ran both SQL files (`schema.sql` and `rls_policies.sql`)

---

## 🎉 Success Checklist

- ✅ Database tables created (leads, applications, tasks)
- ✅ RLS policies applied
- ✅ Edge Function deployed
- ✅ Frontend running on localhost:3000
- ✅ Sample data inserted
- ✅ Tasks visible in dashboard
- ✅ "Mark Complete" button works

---

## 📚 Next Steps

1. Read `SUBMISSION_NOTES.md` for technical details
2. Check `docs/TESTING_GUIDE.md` for comprehensive testing
3. Review `docs/STRIPE_INTEGRATION.md` for payment flow
4. Explore the code with comments explaining each section

---

## 🆘 Need Help?

- Check Supabase logs: Dashboard > Logs
- Review browser console for frontend errors
- Verify environment variables are set correctly
- Ensure database tables were created successfully

---

## 🔒 Security Note

**For Production:**
- Enable RLS on all tables
- Use proper JWT authentication
- Store secrets in environment variables
- Configure CORS properly
- Add rate limiting

---

## 📦 What's Included

```
learnlynk-tech-test/
├── backend/
│   ├── schema.sql              ✅ Section 1
│   ├── rls_policies.sql        ✅ Section 2
│   └── supabase/functions/
│       └── create-task/        ✅ Section 3
│           └── index.ts
├── frontend/
│   └── app/dashboard/today/
│       └── page.tsx            ✅ Section 4
├── docs/
│   ├── STRIPE_INTEGRATION.md   ✅ Section 5
│   └── TESTING_GUIDE.md
├── README.md
├── SUBMISSION_NOTES.md
└── QUICKSTART.md (this file)
```

---

Happy coding! 🚀

**If you found this helpful, please star the repository!**
