// ============================================================================
// LearnLynk CRM - Today's Tasks Dashboard
// Section 4: Mini Frontend Exercise
// ============================================================================
// Description: Next.js page displaying tasks due today with React Query
// Author: [Your Name]
// Date: 10 December 2025
// ============================================================================

"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { createClient } from "@supabase/supabase-js";

// ============================================================================
// Supabase Client Configuration
// ============================================================================
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// ============================================================================
// Type Definitions
// ============================================================================
interface Task {
  id: string;
  title: string;
  description: string;
  type: "call" | "email" | "review";
  application_id: string;
  due_at: string;
  status: string;
  priority: "low" | "medium" | "high" | "urgent";
  assigned_to: string | null;
  created_at: string;
}

// ============================================================================
// API Functions
// ============================================================================

/**
 * Fetches tasks due today
 */
async function fetchTodaysTasks(): Promise<Task[]> {
  // Calculate today's date range (start and end of day in UTC)
  const now = new Date();
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const endOfDay = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    23,
    59,
    59,
    999
  );

  const { data, error } = await supabase
    .from("tasks")
    .select("*")
    .gte("due_at", startOfDay.toISOString())
    .lte("due_at", endOfDay.toISOString())
    .neq("status", "completed")
    .is("deleted_at", null)
    .order("due_at", { ascending: true });

  if (error) {
    console.error("Error fetching tasks:", error);
    throw new Error(`Failed to fetch tasks: ${error.message}`);
  }

  return data || [];
}

/**
 * Marks a task as complete
 */
async function markTaskComplete(taskId: string): Promise<void> {
  const { error } = await supabase
    .from("tasks")
    .update({
      status: "completed",
      completed_at: new Date().toISOString(),
    })
    .eq("id", taskId);

  if (error) {
    console.error("Error updating task:", error);
    throw new Error(`Failed to update task: ${error.message}`);
  }
}

// ============================================================================
// Component: TaskRow
// ============================================================================
interface TaskRowProps {
  task: Task;
  onMarkComplete: (taskId: string) => void;
  isUpdating: boolean;
}

function TaskRow({ task, onMarkComplete, isUpdating }: TaskRowProps) {
  const priorityColors = {
    low: "bg-gray-100 text-gray-800",
    medium: "bg-blue-100 text-blue-800",
    high: "bg-orange-100 text-orange-800",
    urgent: "bg-red-100 text-red-800",
  };

  const typeIcons = {
    call: "📞",
    email: "📧",
    review: "📋",
  };

  return (
    <tr className="border-b border-gray-200 hover:bg-gray-50 transition-colors">
      <td className="px-4 py-3">
        <div className="flex items-center gap-2">
          <span className="text-xl">{typeIcons[task.type]}</span>
          <div>
            <div className="font-medium text-gray-900">{task.title}</div>
            {task.description && (
              <div className="text-sm text-gray-500 mt-1">
                {task.description}
              </div>
            )}
          </div>
        </div>
      </td>
      <td className="px-4 py-3">
        <span className="font-mono text-sm text-gray-600">
          {task.application_id.slice(0, 8)}...
        </span>
      </td>
      <td className="px-4 py-3">
        <div className="text-sm">
          <div className="font-medium text-gray-900">
            {new Date(task.due_at).toLocaleTimeString("en-US", {
              hour: "2-digit",
              minute: "2-digit",
            })}
          </div>
          <div className="text-gray-500">
            {new Date(task.due_at).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
            })}
          </div>
        </div>
      </td>
      <td className="px-4 py-3">
        <span
          className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
            priorityColors[task.priority]
          }`}
        >
          {task.priority}
        </span>
      </td>
      <td className="px-4 py-3">
        <span className="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">
          {task.status}
        </span>
      </td>
      <td className="px-4 py-3">
        <button
          onClick={() => onMarkComplete(task.id)}
          disabled={isUpdating}
          className="px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isUpdating ? "Updating..." : "Mark Complete"}
        </button>
      </td>
    </tr>
  );
}

// ============================================================================
// Component: LoadingSkeleton
// ============================================================================
function LoadingSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="h-8 bg-gray-200 rounded w-1/4 mb-4"></div>
      <div className="space-y-3">
        {[1, 2, 3].map((i) => (
          <div key={i} className="h-16 bg-gray-200 rounded"></div>
        ))}
      </div>
    </div>
  );
}

// ============================================================================
// Component: ErrorDisplay
// ============================================================================
interface ErrorDisplayProps {
  error: Error;
  onRetry: () => void;
}

function ErrorDisplay({ error, onRetry }: ErrorDisplayProps) {
  return (
    <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
      <div className="text-red-600 text-4xl mb-3">⚠️</div>
      <h3 className="text-lg font-semibold text-red-900 mb-2">
        Error Loading Tasks
      </h3>
      <p className="text-red-700 mb-4">{error.message}</p>
      <button
        onClick={onRetry}
        className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
      >
        Try Again
      </button>
    </div>
  );
}

// ============================================================================
// Component: EmptyState
// ============================================================================
function EmptyState() {
  return (
    <div className="text-center py-12">
      <div className="text-6xl mb-4">🎉</div>
      <h3 className="text-xl font-semibold text-gray-900 mb-2">
        No tasks due today!
      </h3>
      <p className="text-gray-600">
        You're all caught up. Enjoy your day!
      </p>
    </div>
  );
}

// ============================================================================
// Main Component: DashboardToday
// ============================================================================
export default function DashboardToday() {
  const queryClient = useQueryClient();
  const [updatingTaskId, setUpdatingTaskId] = useState<string | null>(null);

  // Fetch tasks using React Query
  const {
    data: tasks = [],
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery<Task[], Error>({
    queryKey: ["tasks", "today"],
    queryFn: fetchTodaysTasks,
    refetchInterval: 30000, // Refetch every 30 seconds
    staleTime: 10000, // Consider data stale after 10 seconds
  });

  // Mutation for marking task as complete
  const markCompleteMutation = useMutation({
    mutationFn: markTaskComplete,
    onMutate: async (taskId) => {
      setUpdatingTaskId(taskId);

      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ["tasks", "today"] });

      // Snapshot previous value
      const previousTasks = queryClient.getQueryData<Task[]>([
        "tasks",
        "today",
      ]);

      // Optimistically update UI
      queryClient.setQueryData<Task[]>(["tasks", "today"], (old = []) =>
        old.filter((task) => task.id !== taskId)
      );

      return { previousTasks };
    },
    onError: (err, taskId, context) => {
      // Rollback on error
      if (context?.previousTasks) {
        queryClient.setQueryData(["tasks", "today"], context.previousTasks);
      }
      alert(`Failed to update task: ${err.message}`);
    },
    onSuccess: () => {
      // Refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: ["tasks", "today"] });
    },
    onSettled: () => {
      setUpdatingTaskId(null);
    },
  });

  const handleMarkComplete = (taskId: string) => {
    markCompleteMutation.mutate(taskId);
  };

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Tasks Due Today
          </h1>
          <p className="text-gray-600">
            {new Date().toLocaleDateString("en-US", {
              weekday: "long",
              year: "numeric",
              month: "long",
              day: "numeric",
            })}
          </p>
        </div>

        {/* Main Content */}
        <div className="bg-white rounded-lg shadow overflow-hidden">
          {isLoading ? (
            <div className="p-6">
              <LoadingSkeleton />
            </div>
          ) : isError ? (
            <div className="p-6">
              <ErrorDisplay error={error} onRetry={() => refetch()} />
            </div>
          ) : tasks.length === 0 ? (
            <div className="p-6">
              <EmptyState />
            </div>
          ) : (
            <>
              {/* Stats Bar */}
              <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
                <div className="flex items-center justify-between">
                  <div className="text-sm text-gray-600">
                    <span className="font-semibold text-gray-900">
                      {tasks.length}
                    </span>{" "}
                    {tasks.length === 1 ? "task" : "tasks"} remaining
                  </div>
                  <button
                    onClick={() => refetch()}
                    className="text-sm text-blue-600 hover:text-blue-800 font-medium"
                  >
                    Refresh
                  </button>
                </div>
              </div>

              {/* Table */}
              <div className="overflow-x-auto">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Task
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Application ID
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Due Time
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Priority
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Status
                      </th>
                      <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                        Action
                      </th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {tasks.map((task) => (
                      <TaskRow
                        key={task.id}
                        task={task}
                        onMarkComplete={handleMarkComplete}
                        isUpdating={updatingTaskId === task.id}
                      />
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ============================================================================
// END OF COMPONENT
// ============================================================================
