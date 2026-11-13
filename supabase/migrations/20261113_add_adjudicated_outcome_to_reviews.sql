-- ============================================================
-- RAKSHA KAWACH
-- SGT University Transport Safety and Management System
--
-- Migration: Add Adjudicated Attendance Outcome to Attendance Reviews
-- Date: 13 November 2026
--
-- Purpose:
-- Persists explicit administrative final attendance determinations:
--   'present'           - Legitimate student verified (False Alarm)
--   'absent'            - Confirmed proxy boarding (Student not on bus)
--   'contact_transport' - Inconclusive; requires Transport Dept follow-up
--
-- CRITICAL SAFETY & INTEGRITY ASSURANCES:
-- 1. Strictly transactional (BEGIN ... COMMIT).
-- 2. Purely additive: Does NOT alter or drop public.attendance,
--    public.students, or public.admin_users. Hardware and SMS unaffected.
-- 3. Nullable: Existing review records remain valid with NULL outcome.
--    Historical 'resolved' and 'dismissed' reviews are NOT retroactively
--    assumed to be Present or Absent.
-- 4. Least Privilege Security: Grants UPDATE on adjudicated_outcome
--    to authenticated users subject to administrator-only RLS.
--    Creator ID (admin_id) and attendance_id remain strictly immutable.
-- ============================================================

BEGIN;

-- 1. Add nullable adjudicated_outcome column with CHECK constraint
ALTER TABLE public.attendance_reviews
ADD COLUMN IF NOT EXISTS adjudicated_outcome TEXT
CHECK (adjudicated_outcome IN ('present', 'absent', 'contact_transport'));

-- 2. Create index on adjudicated_outcome for fast KPI and ledger queries
CREATE INDEX IF NOT EXISTS idx_attendance_reviews_adjudicated_outcome
ON public.attendance_reviews(adjudicated_outcome);

-- 3. Update column-level UPDATE privilege for authenticated role
-- Permits updating decision fields and adjudicated_outcome while keeping
-- audit fields (id, attendance_id, admin_id, created_at) immutable.
GRANT UPDATE (
    status,
    decision,
    notes,
    resolved_at,
    adjudicated_outcome
)
ON TABLE public.attendance_reviews
TO authenticated;

COMMIT;

