// ============================================================================
// LearnLynk CRM - Create Task Edge Function
// Section 3: Edge Function Task
// ============================================================================
// Description: Serverless function to create tasks with validation and
//              real-time event broadcasting
// Author: [Your Name]
// Date: 10 December 2025
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

// ============================================================================
// CORS Configuration
// ============================================================================
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================================
// Type Definitions
// ============================================================================
interface CreateTaskRequest {
  application_id: string;
  task_type: "call" | "email" | "review";
  due_at: string;
  tenant_id?: string; // Made optional as it can be extracted from JWT
  title?: string;
  description?: string;
  priority?: "low" | "medium" | "high" | "urgent";
  assigned_to?: string;
}

interface CreateTaskResponse {
  success: boolean;
  task_id?: string;
  error?: string;
}

interface ValidationError {
  field: string;
  message: string;
}

// ============================================================================
// Constants
// ============================================================================
const VALID_TASK_TYPES = ["call", "email", "review"] as const;
const VALID_PRIORITIES = ["low", "medium", "high", "urgent"] as const;

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Validates the incoming request body
 */
function validateRequest(body: CreateTaskRequest): ValidationError[] {
  const errors: ValidationError[] = [];

  // Validate application_id
  if (!body.application_id) {
    errors.push({
      field: "application_id",
      message: "application_id is required",
    });
  } else if (!isValidUUID(body.application_id)) {
    errors.push({
      field: "application_id",
      message: "application_id must be a valid UUID",
    });
  }

  // Validate task_type
  if (!body.task_type) {
    errors.push({
      field: "task_type",
      message: "task_type is required",
    });
  } else if (!VALID_TASK_TYPES.includes(body.task_type)) {
    errors.push({
      field: "task_type",
      message: `task_type must be one of: ${VALID_TASK_TYPES.join(", ")}`,
    });
  }

  // Validate due_at
  if (!body.due_at) {
    errors.push({
      field: "due_at",
      message: "due_at is required",
    });
  } else {
    const dueDate = new Date(body.due_at);
    const now = new Date();

    if (isNaN(dueDate.getTime())) {
      errors.push({
        field: "due_at",
        message: "due_at must be a valid ISO 8601 timestamp",
      });
    } else if (dueDate <= now) {
      errors.push({
        field: "due_at",
        message: "due_at must be in the future",
      });
    }
  }

  // Validate priority if provided
  if (body.priority && !VALID_PRIORITIES.includes(body.priority)) {
    errors.push({
      field: "priority",
      message: `priority must be one of: ${VALID_PRIORITIES.join(", ")}`,
    });
  }

  // Validate assigned_to if provided
  if (body.assigned_to && !isValidUUID(body.assigned_to)) {
    errors.push({
      field: "assigned_to",
      message: "assigned_to must be a valid UUID",
    });
  }

  return errors;
}

/**
 * Checks if a string is a valid UUID
 */
function isValidUUID(uuid: string): boolean {
  const uuidRegex =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(uuid);
}

/**
 * Extracts tenant_id from JWT token
 */
function getTenantIdFromAuth(authHeader: string | null): string | null {
  if (!authHeader) return null;

  try {
    // Extract JWT token (format: "Bearer <token>")
    const token = authHeader.replace("Bearer ", "");

    // Decode JWT (basic decoding without verification - Supabase handles verification)
    const base64Url = token.split(".")[1];
    const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split("")
        .map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2))
        .join("")
    );

    const payload = JSON.parse(jsonPayload);
    return payload.tenant_id || null;
  } catch (error) {
    console.error("Error extracting tenant_id from JWT:", error);
    return null;
  }
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        success: false,
        error: "Method not allowed. Use POST.",
      }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  try {
    // Initialize Supabase client with service role for bypassing RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase configuration missing");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Parse request body
    let requestBody: CreateTaskRequest;
    try {
      requestBody = await req.json();
    } catch (error) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Invalid JSON in request body",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Extract tenant_id from JWT if not provided
    if (!requestBody.tenant_id) {
      const authHeader = req.headers.get("Authorization");
      const tenantId = getTenantIdFromAuth(authHeader);

      if (!tenantId) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "tenant_id is required or must be in JWT",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      requestBody.tenant_id = tenantId;
    }

    // Validate request
    const validationErrors = validateRequest(requestBody);
    if (validationErrors.length > 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Validation failed",
          details: validationErrors,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Verify application exists
    const { data: application, error: appError } = await supabase
      .from("applications")
      .select("id, tenant_id")
      .eq("id", requestBody.application_id)
      .is("deleted_at", null)
      .single();

    if (appError || !application) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Application not found or has been deleted",
        }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Verify tenant_id matches
    if (application.tenant_id !== requestBody.tenant_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Application does not belong to the specified tenant",
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Prepare task data
    const taskData = {
      application_id: requestBody.application_id,
      tenant_id: requestBody.tenant_id,
      type: requestBody.task_type,
      due_at: requestBody.due_at,
      title: requestBody.title || `${requestBody.task_type} task`,
      description: requestBody.description || "",
      priority: requestBody.priority || "medium",
      assigned_to: requestBody.assigned_to || null,
      status: "pending",
    };

    // Insert task into database
    const { data: task, error: insertError } = await supabase
      .from("tasks")
      .insert([taskData])
      .select("id")
      .single();

    if (insertError) {
      console.error("Database error:", insertError);
      throw new Error(`Failed to create task: ${insertError.message}`);
    }

    // Broadcast real-time event via Supabase Realtime
    const channel = supabase.channel("tasks");
    await channel.send({
      type: "broadcast",
      event: "task.created",
      payload: {
        task_id: task.id,
        application_id: requestBody.application_id,
        tenant_id: requestBody.tenant_id,
        task_type: requestBody.task_type,
        due_at: requestBody.due_at,
        created_at: new Date().toISOString(),
      },
    });

    // Log success (useful for debugging)
    console.log(`Task created successfully: ${task.id}`);

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        task_id: task.id,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Unhandled error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "An unexpected error occurred",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

// ============================================================================
// END OF EDGE FUNCTION
// ============================================================================
