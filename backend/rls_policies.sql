-- ============================================================================
-- LearnLynk CRM - Row-Level Security (RLS) Policies
-- Section 2: RLS & Policies Test
-- ============================================================================
-- Description: Multi-tenant security policies for leads, applications, and tasks
-- Author: Kurlepu Rajesh
-- Date: 10 December 2025
-- ============================================================================

-- ============================================================================
-- SUPPORTING TABLES (Reference)
-- ============================================================================
-- These tables are referenced in the RLS policies but not created here
-- They should exist in your auth schema or be created separately:
--
-- user_teams(user_id UUID, team_id UUID)
-- teams(team_id UUID, name VARCHAR, tenant_id UUID)
-- auth.users(id UUID, role VARCHAR, tenant_id UUID)
-- ============================================================================

-- ============================================================================
-- LEADS TABLE - RLS POLICIES
-- ============================================================================

-- Enable Row-Level Security on leads table
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- POLICY: Select Leads
-- ----------------------------------------------------------------------------
-- Rules:
-- 1. Users can only see leads within their tenant (tenant isolation)
-- 2. Admins can see all leads in their tenant
-- 3. Counselors can see leads assigned to them (owner_id matches)
-- 4. Counselors can see leads assigned to any team they belong to
-- ----------------------------------------------------------------------------

CREATE POLICY "select_leads_policy" ON leads
FOR SELECT
USING (
    -- Enforce tenant boundary (critical for data isolation)
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    -- Exclude soft-deleted records
    deleted_at IS NULL
    AND
    (
        -- Rule 1: Admin role - full access within tenant
        (auth.jwt() ->> 'role') = 'admin'
        
        OR
        
        -- Rule 2: Lead is assigned to the current user
        owner_id = auth.uid()
        
        OR
        
        -- Rule 3: Lead is assigned to a team the user belongs to
        EXISTS (
            SELECT 1
            FROM user_teams ut
            WHERE ut.user_id = auth.uid()
              AND ut.team_id = leads.team_id
        )
    )
);

COMMENT ON POLICY "select_leads_policy" ON leads IS 
'Allows users to view leads they own, leads in their team, or all leads if admin';

-- ----------------------------------------------------------------------------
-- POLICY: Insert Leads
-- ----------------------------------------------------------------------------
-- Rules:
-- 1. Users can only create leads in their own tenant
-- 2. Only admins and counselors can create leads
-- 3. User's tenant_id must match the lead's tenant_id
-- ----------------------------------------------------------------------------

CREATE POLICY "insert_leads_policy" ON leads
FOR INSERT
WITH CHECK (
    -- Enforce tenant boundary
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    -- Only allow specific roles to create leads
    (auth.jwt() ->> 'role') IN ('admin', 'counselor')
);

COMMENT ON POLICY "insert_leads_policy" ON leads IS 
'Allows admins and counselors to create leads within their tenant';

-- ----------------------------------------------------------------------------
-- POLICY: Update Leads
-- ----------------------------------------------------------------------------
-- Rules:
-- 1. Users can only update leads in their tenant
-- 2. Admins can update any lead in their tenant
-- 3. Counselors can only update leads they own or that belong to their team
-- ----------------------------------------------------------------------------

CREATE POLICY "update_leads_policy" ON leads
FOR UPDATE
USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    deleted_at IS NULL
    AND
    (
        (auth.jwt() ->> 'role') = 'admin'
        OR
        owner_id = auth.uid()
        OR
        EXISTS (
            SELECT 1
            FROM user_teams ut
            WHERE ut.user_id = auth.uid()
              AND ut.team_id = leads.team_id
        )
    )
)
WITH CHECK (
    -- Ensure updated lead stays in the same tenant
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
);

COMMENT ON POLICY "update_leads_policy" ON leads IS 
'Allows users to update leads they have access to within their tenant';

-- ----------------------------------------------------------------------------
-- POLICY: Delete Leads (Soft Delete)
-- ----------------------------------------------------------------------------
-- Rules:
-- 1. Only admins can delete leads
-- 2. Must be within the same tenant
-- ----------------------------------------------------------------------------

CREATE POLICY "delete_leads_policy" ON leads
FOR UPDATE -- Soft delete is an UPDATE operation
USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    (auth.jwt() ->> 'role') = 'admin'
)
WITH CHECK (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    deleted_at IS NOT NULL -- Ensure it's a soft delete operation
);

COMMENT ON POLICY "delete_leads_policy" ON leads IS 
'Allows only admins to soft-delete leads within their tenant';

-- ============================================================================
-- APPLICATIONS TABLE - RLS POLICIES
-- ============================================================================

-- Enable Row-Level Security on applications table
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- POLICY: Select Applications
-- ----------------------------------------------------------------------------
-- Rules:
-- 1. Users can see applications if they have access to the parent lead
-- 2. Tenant isolation enforced
-- ----------------------------------------------------------------------------

CREATE POLICY "select_applications_policy" ON applications
FOR SELECT
USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    deleted_at IS NULL
    AND
    (
        -- Admin has full access
        (auth.jwt() ->> 'role') = 'admin'
        
        OR
        
        -- User has access to the parent lead
        EXISTS (
            SELECT 1
            FROM leads l
            WHERE l.id = applications.lead_id
              AND l.tenant_id = applications.tenant_id
              AND l.deleted_at IS NULL
              AND (
                  l.owner_id = auth.uid()
                  OR
                  EXISTS (
                      SELECT 1
                      FROM user_teams ut
                      WHERE ut.user_id = auth.uid()
                        AND ut.team_id = l.team_id
                  )
              )
        )
    )
);

COMMENT ON POLICY "select_applications_policy" ON applications IS 
'Allows users to view applications for leads they have access to';

-- ----------------------------------------------------------------------------
-- POLICY: Insert Applications
-- ----------------------------------------------------------------------------

CREATE POLICY "insert_applications_policy" ON applications
FOR INSERT
WITH CHECK (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    (auth.jwt() ->> 'role') IN ('admin', 'counselor')
    AND
    -- Ensure the parent lead exists and user has access
    EXISTS (
        SELECT 1
        FROM leads l
        WHERE l.id = applications.lead_id
          AND l.tenant_id = applications.tenant_id
          AND l.deleted_at IS NULL
          AND (
              (auth.jwt() ->> 'role') = 'admin'
              OR
              l.owner_id = auth.uid()
              OR
              EXISTS (
                  SELECT 1
                  FROM user_teams ut
                  WHERE ut.user_id = auth.uid()
                    AND ut.team_id = l.team_id
              )
          )
    )
);

COMMENT ON POLICY "insert_applications_policy" ON applications IS 
'Allows users to create applications for leads they have access to';

-- ----------------------------------------------------------------------------
-- POLICY: Update Applications
-- ----------------------------------------------------------------------------

CREATE POLICY "update_applications_policy" ON applications
FOR UPDATE
USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    deleted_at IS NULL
    AND
    (
        (auth.jwt() ->> 'role') = 'admin'
        OR
        EXISTS (
            SELECT 1
            FROM leads l
            WHERE l.id = applications.lead_id
              AND l.tenant_id = applications.tenant_id
              AND l.deleted_at IS NULL
              AND (
                  l.owner_id = auth.uid()
                  OR
                  EXISTS (
                      SELECT 1
                      FROM user_teams ut
                      WHERE ut.user_id = auth.uid()
                        AND ut.team_id = l.team_id
                  )
              )
        )
    )
)
WITH CHECK (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
);

COMMENT ON POLICY "update_applications_policy" ON applications IS 
'Allows users to update applications for leads they have access to';

-- ============================================================================
-- TASKS TABLE - RLS POLICIES
-- ============================================================================

-- Enable Row-Level Security on tasks table
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- POLICY: Select Tasks
-- ----------------------------------------------------------------------------

CREATE POLICY "select_tasks_policy" ON tasks
FOR SELECT
USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    deleted_at IS NULL
    AND
    (
        -- Admin has full access
        (auth.jwt() ->> 'role') = 'admin'
        
        OR
        
        -- Task is assigned to the current user
        assigned_to = auth.uid()
        
        OR
        
        -- User has access to the parent application/lead
        EXISTS (
            SELECT 1
            FROM applications app
            INNER JOIN leads l ON l.id = app.lead_id
            WHERE app.id = tasks.application_id
              AND app.tenant_id = tasks.tenant_id
              AND app.deleted_at IS NULL
              AND l.deleted_at IS NULL
              AND (
                  l.owner_id = auth.uid()
                  OR
                  EXISTS (
                      SELECT 1
                      FROM user_teams ut
                      WHERE ut.user_id = auth.uid()
                        AND ut.team_id = l.team_id
                  )
              )
        )
    )
);

COMMENT ON POLICY "select_tasks_policy" ON tasks IS 
'Allows users to view tasks assigned to them or related to their leads';

-- ----------------------------------------------------------------------------
-- POLICY: Insert Tasks
-- ----------------------------------------------------------------------------

CREATE POLICY "insert_tasks_policy" ON tasks
FOR INSERT
WITH CHECK (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    (auth.jwt() ->> 'role') IN ('admin', 'counselor')
    AND
    -- Ensure the parent application exists and user has access
    EXISTS (
        SELECT 1
        FROM applications app
        INNER JOIN leads l ON l.id = app.lead_id
        WHERE app.id = tasks.application_id
          AND app.tenant_id = tasks.tenant_id
          AND app.deleted_at IS NULL
          AND l.deleted_at IS NULL
          AND (
              (auth.jwt() ->> 'role') = 'admin'
              OR
              l.owner_id = auth.uid()
              OR
              EXISTS (
                  SELECT 1
                  FROM user_teams ut
                  WHERE ut.user_id = auth.uid()
                    AND ut.team_id = l.team_id
              )
          )
    )
);

COMMENT ON POLICY "insert_tasks_policy" ON tasks IS 
'Allows users to create tasks for applications they have access to';

-- ----------------------------------------------------------------------------
-- POLICY: Update Tasks
-- ----------------------------------------------------------------------------

CREATE POLICY "update_tasks_policy" ON tasks
FOR UPDATE
USING (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
    AND
    deleted_at IS NULL
    AND
    (
        (auth.jwt() ->> 'role') = 'admin'
        OR
        assigned_to = auth.uid()
        OR
        EXISTS (
            SELECT 1
            FROM applications app
            INNER JOIN leads l ON l.id = app.lead_id
            WHERE app.id = tasks.application_id
              AND app.tenant_id = tasks.tenant_id
              AND app.deleted_at IS NULL
              AND l.deleted_at IS NULL
              AND (
                  l.owner_id = auth.uid()
                  OR
                  EXISTS (
                      SELECT 1
                      FROM user_teams ut
                      WHERE ut.user_id = auth.uid()
                        AND ut.team_id = l.team_id
                  )
              )
        )
    )
)
WITH CHECK (
    tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
);

COMMENT ON POLICY "update_tasks_policy" ON tasks IS 
'Allows users to update tasks they are assigned or have access through leads';

-- ============================================================================
-- HELPER FUNCTIONS (Optional)
-- ============================================================================

-- Function to check if a user has access to a lead
CREATE OR REPLACE FUNCTION user_has_lead_access(lead_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    has_access BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM leads l
        WHERE l.id = lead_id
          AND l.tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
          AND l.deleted_at IS NULL
          AND (
              (auth.jwt() ->> 'role') = 'admin'
              OR
              l.owner_id = auth.uid()
              OR
              EXISTS (
                  SELECT 1
                  FROM user_teams ut
                  WHERE ut.user_id = auth.uid()
                    AND ut.team_id = l.team_id
              )
          )
    ) INTO has_access;
    
    RETURN has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION user_has_lead_access IS 
'Helper function to check if current user has access to a specific lead';

-- ============================================================================
-- TESTING QUERIES (Commented out - use for validation)
-- ============================================================================

/*
-- Test 1: Counselor should only see their own leads
SET request.jwt.claim.role = 'counselor';
SET request.jwt.claim.tenant_id = '550e8400-e29b-41d4-a716-446655440000';
SELECT * FROM leads; -- Should only return leads owned by this counselor

-- Test 2: Admin should see all leads in tenant
SET request.jwt.claim.role = 'admin';
SET request.jwt.claim.tenant_id = '550e8400-e29b-41d4-a716-446655440000';
SELECT * FROM leads; -- Should return all leads in tenant

-- Test 3: Insert lead as counselor
INSERT INTO leads (tenant_id, first_name, last_name, email, owner_id)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'Test',
    'Lead',
    'test@example.com',
    auth.uid()
); -- Should succeed

-- Test 4: Try to insert lead in different tenant (should fail)
INSERT INTO leads (tenant_id, first_name, last_name, email, owner_id)
VALUES (
    'different-tenant-id',
    'Test',
    'Lead',
    'test@example.com',
    auth.uid()
); -- Should fail with RLS violation
*/

-- ============================================================================
-- END OF RLS POLICIES
-- ============================================================================
