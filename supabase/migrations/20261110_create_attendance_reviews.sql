-- ==============================================================================
-- Raksha Kawach — SGT University Transport Safety and Management System
-- Migration: Additive Attendance Reviews Table (Anti-Proxy Conflict Resolution)
-- Date: 10 November 2026
--
-- IMPORTANT SAFETY NOTICE:
-- 1. This migration is strictly additive.
-- 2. It does NOT modify or drop existing tables, columns, or triggers.
-- 3. The original public.attendance table remains completely immutable.
-- 4. RLS policies restrict both read and write access strictly to verified
--    administrators in public.admin_users (auth.uid() = user_id).
-- ==============================================================================

-- 1. Create table public.attendance_reviews
CREATE TABLE IF NOT EXISTS public.attendance_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_id UUID NOT NULL REFERENCES public.attendance(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES auth.users(id),
    status TEXT NOT NULL CHECK (status IN ('pending', 'resolved', 'dismissed')),
    decision TEXT NOT NULL CHECK (decision IN ('investigate', 'resolved', 'dismissed')),
    notes TEXT NOT NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Indexes for efficient lookup
CREATE INDEX IF NOT EXISTS idx_attendance_reviews_attendance_id 
    ON public.attendance_reviews(attendance_id);
CREATE INDEX IF NOT EXISTS idx_attendance_reviews_status 
    ON public.attendance_reviews(status);
CREATE INDEX IF NOT EXISTS idx_attendance_reviews_created_at 
    ON public.attendance_reviews(created_at DESC);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.attendance_reviews ENABLE ROW LEVEL SECURITY;

-- 4. SELECT Policy: Only verified administrators in public.admin_users can read reviews
CREATE POLICY "Allow verified admins to read attendance reviews"
    ON public.attendance_reviews
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

-- 5. INSERT Policy: Only verified administrators in public.admin_users can insert reviews
CREATE POLICY "Allow verified admins to insert attendance reviews"
    ON public.attendance_reviews
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = admin_id AND
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

-- 6. UPDATE Policy: Only verified administrators can update their reviews
CREATE POLICY "Allow verified admins to update attendance reviews"
    ON public.attendance_reviews
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_users
            WHERE admin_users.user_id = auth.uid()
        )
    );

