-- ============================================================================
-- LearnLynk CRM - Database Schema
-- Section 1: Supabase Schema Challenge
-- ============================================================================
-- Description: Complete schema for multi-tenant admissions CRM with leads,
--              applications, and tasks management
-- Author: Kurlepu Rajesh
-- Date: 10 December 2025
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TABLE: leads
-- ============================================================================
-- Purpose: Stores prospective student information and tracks them through
--          the admission pipeline
-- ============================================================================

CREATE TABLE IF NOT EXISTS leads (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- Lead information
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    
    -- Lead source tracking
    source VARCHAR(50), -- e.g., 'website', 'referral', 'event', 'social_media'
    
    -- Assignment and ownership
    owner_id UUID, -- References auth.users (counselor assigned)
    team_id UUID,  -- References teams table for team-based access
    
    -- Pipeline stage
    stage VARCHAR(50) DEFAULT 'new', -- e.g., 'new', 'contacted', 'qualified', 'converted'
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ -- Soft delete support
);

-- Comments for documentation
COMMENT ON TABLE leads IS 'Prospective students in the admissions pipeline';
COMMENT ON COLUMN leads.tenant_id IS 'Organization/institution identifier for multi-tenancy';
COMMENT ON COLUMN leads.owner_id IS 'Counselor assigned to this lead';
COMMENT ON COLUMN leads.team_id IS 'Team with shared access to this lead';
COMMENT ON COLUMN leads.stage IS 'Current position in the sales pipeline';

-- ============================================================================
-- TABLE: applications
-- ============================================================================
-- Purpose: Formal applications submitted by leads for programs
-- ============================================================================

CREATE TABLE IF NOT EXISTS applications (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- Relationship to lead
    lead_id UUID NOT NULL,
    
    -- Application details
    program VARCHAR(255), -- e.g., 'MBA', 'Computer Science', 'Engineering'
    intake VARCHAR(50),   -- e.g., 'Fall 2026', 'Spring 2026'
    
    -- Application status
    status VARCHAR(50) DEFAULT 'draft', -- e.g., 'draft', 'submitted', 'under_review', 'accepted', 'rejected'
    
    -- Payment tracking
    payment_status VARCHAR(50) DEFAULT 'unpaid', -- e.g., 'unpaid', 'pending', 'paid', 'refunded'
    application_fee DECIMAL(10, 2),
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    -- Foreign key constraint
    CONSTRAINT fk_applications_lead 
        FOREIGN KEY (lead_id) 
        REFERENCES leads(id) 
        ON DELETE CASCADE
);

COMMENT ON TABLE applications IS 'Formal program applications submitted by leads';
COMMENT ON COLUMN applications.lead_id IS 'Reference to the lead who submitted this application';
COMMENT ON COLUMN applications.payment_status IS 'Tracks application fee payment state';

-- ============================================================================
-- TABLE: tasks
-- ============================================================================
-- Purpose: Action items and follow-ups for applications and leads
-- ============================================================================

CREATE TABLE IF NOT EXISTS tasks (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    
    -- Relationship to application
    application_id UUID NOT NULL,
    
    -- Task details
    title VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL,
    priority VARCHAR(20) DEFAULT 'medium', -- e.g., 'low', 'medium', 'high', 'urgent'
    
    -- Task scheduling
    due_at TIMESTAMPTZ NOT NULL,
    
    -- Task status
    status VARCHAR(50) DEFAULT 'pending', -- e.g., 'pending', 'in_progress', 'completed', 'cancelled'
    
    -- Assignment
    assigned_to UUID, -- References auth.users
    
    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    
    -- Foreign key constraint
    CONSTRAINT fk_tasks_application 
        FOREIGN KEY (application_id) 
        REFERENCES applications(id) 
        ON DELETE CASCADE,
    
    -- Check constraints
    CONSTRAINT check_task_type 
        CHECK (type IN ('call', 'email', 'review')),
    
    CONSTRAINT check_due_date 
        CHECK (due_at >= created_at)
);

COMMENT ON TABLE tasks IS 'Action items and follow-ups for application management';
COMMENT ON COLUMN tasks.application_id IS 'Application this task relates to';
COMMENT ON COLUMN tasks.type IS 'Task category: call, email, or review';
COMMENT ON COLUMN tasks.due_at IS 'Deadline for task completion';

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Purpose: Optimize common query patterns for performance
-- ============================================================================

-- Leads table indexes
CREATE INDEX idx_leads_tenant_id ON leads(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_owner_id ON leads(owner_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_team_id ON leads(team_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_stage ON leads(stage) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_created_at ON leads(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_leads_email ON leads(email) WHERE deleted_at IS NULL;

-- Composite index for common queries: fetch leads by owner and stage
CREATE INDEX idx_leads_owner_stage ON leads(owner_id, stage, created_at DESC) 
    WHERE deleted_at IS NULL;

-- Composite index for team-based queries
CREATE INDEX idx_leads_team_stage ON leads(team_id, stage, created_at DESC) 
    WHERE deleted_at IS NULL;

-- Applications table indexes
CREATE INDEX idx_applications_tenant_id ON applications(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_applications_lead_id ON applications(lead_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_applications_status ON applications(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_applications_payment_status ON applications(payment_status) WHERE deleted_at IS NULL;
CREATE INDEX idx_applications_created_at ON applications(created_at DESC) WHERE deleted_at IS NULL;

-- Composite index: fetch applications by lead and status
CREATE INDEX idx_applications_lead_status ON applications(lead_id, status) 
    WHERE deleted_at IS NULL;

-- Tasks table indexes
CREATE INDEX idx_tasks_tenant_id ON tasks(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_application_id ON tasks(application_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_status ON tasks(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_due_at ON tasks(due_at) WHERE deleted_at IS NULL AND status != 'completed';
CREATE INDEX idx_tasks_type ON tasks(type) WHERE deleted_at IS NULL;

-- Composite index: fetch tasks due today for a specific user
CREATE INDEX idx_tasks_due_today ON tasks(due_at, assigned_to, status) 
    WHERE deleted_at IS NULL;

-- Composite index: fetch pending tasks by application
CREATE INDEX idx_tasks_app_pending ON tasks(application_id, status, due_at) 
    WHERE deleted_at IS NULL;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
-- Purpose: Automatically update timestamps and maintain data integrity
-- ============================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables
CREATE TRIGGER update_leads_updated_at 
    BEFORE UPDATE ON leads 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at 
    BEFORE UPDATE ON applications 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at 
    BEFORE UPDATE ON tasks 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================
-- Uncomment to insert sample data for development/testing

/*
-- Sample tenant
INSERT INTO leads (tenant_id, first_name, last_name, email, phone, source, stage, owner_id)
VALUES 
    ('550e8400-e29b-41d4-a716-446655440000', 'John', 'Doe', 'john.doe@example.com', '+1234567890', 'website', 'new', '550e8400-e29b-41d4-a716-446655440001'),
    ('550e8400-e29b-41d4-a716-446655440000', 'Jane', 'Smith', 'jane.smith@example.com', '+1234567891', 'referral', 'contacted', '550e8400-e29b-41d4-a716-446655440001');
*/

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
