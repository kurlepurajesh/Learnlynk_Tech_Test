# Reviewer Checklist

**For**: LearnLynk Technical Assessment Review  
**Date**: 10 December 2025

Use this checklist to evaluate the submission systematically.

---

## ✅ Section 1: Database Schema (45 minutes)

### Requirements Met
- [ ] Three tables created: `leads`, `applications`, `tasks`
- [ ] All tables include: `id`, `tenant_id`, `created_at`, `updated_at`
- [ ] `applications` references `leads(id)`
- [ ] `tasks` references `applications(id)`
- [ ] Proper FOREIGN KEY constraints with ON DELETE CASCADE
- [ ] Indexing for common queries (leads by owner, stage, created_at)
- [ ] Indexing for applications by lead
- [ ] Indexing for tasks due today
- [ ] Constraint: `tasks.due_at >= created_at`
- [ ] Check constraint: `task.type IN ('call', 'email', 'review')`

### Bonus Points
- [ ] Additional realistic fields for CRM usage
- [ ] Soft delete support (`deleted_at`)
- [ ] Composite indexes for performance
- [ ] Auto-updating timestamps with triggers
- [ ] Comprehensive inline comments
- [ ] Sample test data (commented out)

### Code Quality
- [ ] Clean, readable SQL
- [ ] Consistent naming conventions
- [ ] Proper indentation
- [ ] Organized structure (tables → indexes → triggers)

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## ✅ Section 2: RLS Policies (30 minutes)

### Requirements Met
- [ ] RLS enabled on `leads` table
- [ ] SELECT policy: Counselors see assigned leads
- [ ] SELECT policy: Counselors see team leads
- [ ] SELECT policy: Admins see all tenant leads
- [ ] INSERT policy: Counselors/admins can create leads in their tenant
- [ ] Tenant isolation enforced
- [ ] Uses `auth.jwt()` for role extraction
- [ ] Uses `user_teams` for team membership

### Bonus Points
- [ ] RLS policies for `applications` and `tasks` tables
- [ ] UPDATE and DELETE policies
- [ ] Helper functions for access checking
- [ ] Comprehensive documentation
- [ ] Test queries provided
- [ ] Performance-optimized queries (EXISTS vs JOINs)

### Security
- [ ] No cross-tenant data leakage possible
- [ ] Proper role-based access control
- [ ] Tenant ID checked in every policy
- [ ] Soft delete awareness in policies

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## ✅ Section 3: Edge Function (45 minutes)

### Requirements Met
- [ ] Accepts POST request
- [ ] Validates `task_type` in ['call', 'email', 'review']
- [ ] Validates `due_at` is in the future
- [ ] Inserts into `tasks` table
- [ ] Emits Supabase Realtime broadcast event: "task.created"
- [ ] Returns `{ success: true, task_id: "..." }`
- [ ] Written in TypeScript
- [ ] Uses Supabase client with service role
- [ ] Returns proper status codes (400, 200)

### Bonus Points
- [ ] CORS handling
- [ ] Application existence verification
- [ ] UUID format validation
- [ ] Tenant ID extraction from JWT
- [ ] Detailed error messages
- [ ] 403 for forbidden, 404 for not found
- [ ] Try-catch error handling
- [ ] Type definitions for request/response
- [ ] Helper functions for validation

### Code Quality
- [ ] Clean, readable TypeScript
- [ ] Proper separation of concerns
- [ ] Comprehensive comments
- [ ] Error logging for debugging

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## ✅ Section 4: Frontend Dashboard (30 minutes)

### Requirements Met
- [ ] Next.js page at `/dashboard/today`
- [ ] Fetches tasks due today from Supabase
- [ ] Displays in a table
- [ ] Shows: Task title, Application ID, Due date, Status
- [ ] "Mark Complete" button
- [ ] Updates Supabase on click
- [ ] Refreshes UI after update
- [ ] Shows loading state
- [ ] Shows error state

### Bonus Points
- [ ] React Query for state management
- [ ] Optimistic UI updates
- [ ] Automatic background refetching
- [ ] Empty state design
- [ ] Error boundary with retry
- [ ] Task count statistics
- [ ] Priority color coding
- [ ] Type icons for task types
- [ ] Responsive design
- [ ] TailwindCSS styling
- [ ] Complete Next.js configuration
- [ ] Environment variable template

### User Experience
- [ ] Intuitive interface
- [ ] Clear loading indicators
- [ ] Helpful error messages
- [ ] Smooth transitions
- [ ] Accessible (keyboard navigation, ARIA)

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## ✅ Section 5: Stripe Integration (30 minutes)

### Requirements Met (8-12 lines)
- [ ] Creating Checkout session
- [ ] Storing payment_request
- [ ] Handling Stripe webhook
- [ ] Updating payment status
- [ ] Updating application stage

### Bonus Points
- [ ] Detailed code examples (not just explanation)
- [ ] Webhook signature verification
- [ ] Idempotent payment processing
- [ ] Database transaction for atomicity
- [ ] Payment audit trail
- [ ] Error handling and retry logic
- [ ] Test mode instructions
- [ ] Security considerations
- [ ] Metadata validation
- [ ] Automatic workflow advancement

### Clarity
- [ ] Easy to understand
- [ ] Implementable as-is
- [ ] Addresses edge cases
- [ ] Production-ready approach

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## 📚 Documentation Quality

### README.md
- [ ] Clear project overview
- [ ] Setup instructions
- [ ] File structure explained
- [ ] Key design decisions documented
- [ ] Contact information provided

### Additional Documentation
- [ ] Quick start guide
- [ ] Testing instructions
- [ ] Architecture diagrams
- [ ] Submission notes with assumptions

### Code Comments
- [ ] Inline comments where needed
- [ ] Function/component documentation
- [ ] Complex logic explained

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## 🏗️ Project Structure & Organization

### File Organization
- [ ] Logical folder structure
- [ ] Clear separation of concerns
- [ ] Consistent naming conventions
- [ ] Appropriate file locations

### Configuration
- [ ] All necessary config files included
- [ ] Environment variables documented
- [ ] Dependencies properly specified
- [ ] .gitignore present

**Score**: _____ / 10

**Notes**:
```
[Reviewer notes here]
```

---

## 🎯 Overall Assessment

### Technical Skills (40%)
- Database design: _____ / 10
- Backend development: _____ / 10
- Frontend development: _____ / 10
- Security awareness: _____ / 10

**Subtotal**: _____ / 40

### Problem Solving (30%)
- Understanding requirements: _____ / 10
- Architectural thinking: _____ / 10
- Edge case handling: _____ / 10

**Subtotal**: _____ / 30

### Code Quality (20%)
- Readability: _____ / 10
- Maintainability: _____ / 10

**Subtotal**: _____ / 20

### Communication (10%)
- Documentation quality: _____ / 10

**Subtotal**: _____ / 10

---

## 📊 Final Score

| Category | Score | Weight | Weighted |
|----------|-------|--------|----------|
| Technical Skills | __/40 | 40% | __/40 |
| Problem Solving | __/30 | 30% | __/30 |
| Code Quality | __/20 | 20% | __/20 |
| Communication | __/10 | 10% | __/10 |
| **TOTAL** | | | **__/100** |

---

## 🎓 Strengths

1. ________________________________________________
2. ________________________________________________
3. ________________________________________________
4. ________________________________________________
5. ________________________________________________

---

## 🔧 Areas for Improvement

1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

---

## 💬 Recommendation

- [ ] **Strong Yes** - Exceeds expectations, ready for next round
- [ ] **Yes** - Meets requirements, good candidate
- [ ] **Maybe** - Some concerns, needs discussion
- [ ] **No** - Does not meet requirements

---

## 📝 Interviewer Notes

### Technical Discussion Topics
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

### Questions for Candidate
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

### Next Steps
- [ ] Schedule technical interview
- [ ] Request code walkthrough
- [ ] Discuss architectural decisions
- [ ] Review specific sections in detail

---

## 📞 Follow-up Actions

**Immediate**:
- [ ] Send feedback email
- [ ] Schedule next interview (if applicable)
- [ ] Share decision with hiring team

**For Next Round**:
- [ ] Prepare deeper technical questions
- [ ] Set up live coding session
- [ ] Plan team introduction

---

**Reviewed By**: _________________________  
**Date**: _________________________  
**Time Spent**: ________ minutes  

---

## 🎯 Quick Reference: What Good Looks Like

### Section 1 (Schema)
✅ Beyond just basic tables - added realistic fields  
✅ Composite indexes for performance  
✅ Soft deletes for audit trails  
✅ Auto-updating timestamps

### Section 2 (RLS)
✅ Complete CRUD policies, not just SELECT  
✅ Policies for all tables, not just leads  
✅ Team-based access with proper JOINs  
✅ Performance-optimized queries

### Section 3 (Edge Function)
✅ **Realtime broadcast implemented** (often missed!)  
✅ Comprehensive validation beyond requirements  
✅ Proper error codes (400, 403, 404, 500)  
✅ TypeScript with type definitions

### Section 4 (Frontend)
✅ React Query (not just useState)  
✅ Optimistic updates for instant feedback  
✅ Loading/error/empty states  
✅ Complete Next.js setup (not just one file)

### Section 5 (Stripe)
✅ Actual code, not just text explanation  
✅ Idempotent webhook handling  
✅ Database transactions  
✅ Security considerations detailed

---

## ⚡ Red Flags to Watch For

❌ Missing Realtime broadcast in Edge Function  
❌ No error handling  
❌ Hard-coded values  
❌ Missing RLS policies  
❌ No documentation  
❌ Incomplete Next.js setup  
❌ No consideration for production edge cases  
❌ Copy-paste without understanding  

---

**End of Checklist**
