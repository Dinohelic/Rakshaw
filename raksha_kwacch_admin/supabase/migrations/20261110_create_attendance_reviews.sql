
-- ============================================================
-- RAKSHA KAWACH
-- SGT University Transport Safety and Management System
--
-- Migration: Create Attendance Reviews
-- Purpose: Persistent Anti-Proxy Conflict Resolution
--
-- IMPORTANT:
-- Run only after confirming attendance_reviews does not exist.
-- Preserves existing attendance records and hardware workflow.
-- ============================================================

BEGIN;

-- 1. Create the review table.
-- Do not use IF NOT EXISTS: fail safely if already created.

CREATE TABLE public.attendance_reviews (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    attendance_id UUID NOT NULL
        REFERENCES public.attendance(id)
        ON DELETE RESTRICT,

    admin_id UUID NOT NULL
        REFERENCES auth.users(id),

    status TEXT NOT NULL
        CHECK (status IN (
            'pending',
            'resolved',
            'dismissed'
        )),

    decision TEXT NOT NULL
        CHECK (decision IN (
            'investigate',
            'resolved',
            'dismissed'
        )),

    notes TEXT NOT NULL
        CHECK (length(btrim(notes)) > 0),

    resolved_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Exactly one review per attendance event.
    CONSTRAINT uq_attendance_reviews_attendance
        UNIQUE (attendance_id),

    -- Prevent contradictory decisions.
    CONSTRAINT chk_review_decision_consistency
        CHECK (
            (
                status = 'pending'
                AND decision = 'investigate'
                AND resolved_at IS NULL
            )
            OR
            (
                status = 'resolved'
                AND decision = 'resolved'
                AND resolved_at IS NOT NULL
            )
            OR
            (
                status = 'dismissed'
                AND decision = 'dismissed'
                AND resolved_at IS NOT NULL
            )
        )
);

-- 2. Indexes.
-- UNIQUE(attendance_id) already creates an index.

CREATE INDEX idx_attendance_reviews_status
    ON public.attendance_reviews(status);

CREATE INDEX idx_attendance_reviews_created_at
    ON public.attendance_reviews(created_at DESC);

-- 3. Enable Row Level Security.

ALTER TABLE public.attendance_reviews
ENABLE ROW LEVEL SECURITY;

-- 4. Remove broad default privileges.
-- The authenticated role must not retain table-wide UPDATE.

REVOKE ALL ON TABLE public.attendance_reviews
FROM PUBLIC, anon, authenticated;

-- 5. Grant minimum privileges.
-- All operations remain subject to RLS.

GRANT SELECT, INSERT
ON TABLE public.attendance_reviews
TO authenticated;

-- Immutable:
-- id, attendance_id, admin_id, created_at.

GRANT UPDATE (
    status,
    decision,
    notes,
    resolved_at
)
ON TABLE public.attendance_reviews
TO authenticated;

-- 6. SELECT policy.
-- Only members of public.admin_users may read.

CREATE POLICY "Allow verified admins to read attendance reviews"
ON public.attendance_reviews
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users AS au
        WHERE au.user_id = (SELECT auth.uid())
    )
);

-- 7. INSERT policy.
-- Review creator must be the signed-in admin.

CREATE POLICY "Allow verified admins to insert attendance reviews"
ON public.attendance_reviews
FOR INSERT
TO authenticated
WITH CHECK (
    admin_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1
        FROM public.admin_users AS au
        WHERE au.user_id = (SELECT auth.uid())
    )
);

-- 8. UPDATE policy.
-- Authorized administrators may update decision fields only.
-- Column-level privileges prevent changing the creator ID.

CREATE POLICY "Allow verified admins to update attendance reviews"
ON public.attendance_reviews
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users AS au
        WHERE au.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.admin_users AS au
        WHERE au.user_id = (SELECT auth.uid())
    )
);

-- 9. No DELETE policy or DELETE privilege.
-- Attendance reviews are retained for audit purposes.

COMMIT;
