-- ============================================================
-- RAKSHA KAWACH — SGT University Transport Safety and Management System
--
-- Migration: Add Student Auth Identity Mapping & Student RLS Policies
-- Migration File: 20261115_student_identity_and_rls.sql
-- Date: 15 November 2026
--
-- PURPOSE:
-- Safely establishes an authoritative 1:1 relationship between Supabase
-- auth users (auth.users) and registered student profiles (public.students).
-- Enforces strict Row Level Security (RLS) so authenticated students can:
--   1. Read only their own profile and card blocking status.
--   2. Read only their own attendance scan history.
--   3. Read only their own disciplinary strike records.
--   4. Read only their own card action audit logs.
--   5. View, insert, and update only their own phone GPS location.
--
-- PREREQUISITES:
-- 1. 20261110_create_attendance_reviews.sql applied.
-- 2. 20261113_add_adjudicated_outcome_to_reviews.sql applied.
-- 3. 20261114_three_strike_card_blocking.sql applied.
--
-- SECURITY & INTEGRITY ASSURANCES:
-- 1. Strictly additive & transactional (BEGIN ... COMMIT).
-- 2. Preserves all 4 existing students (STU001-STU004) and historical attendance records intact.
-- 3. Existing administrative privileges and RLS policies remain fully functional.
-- 4. No redundant index created: the UNIQUE constraint on auth_user_id automatically
--    creates a unique B-tree index in PostgreSQL (students_auth_user_id_key).
-- 5. No mutation privileges (INSERT, UPDATE, DELETE) granted to students on
--    attendance, attendance_reviews, student_strikes, transport_card_actions, or students.
-- 6. GPS updates are bound by WITH CHECK to prevent student_id impersonation.
-- 7. Prevents RLS recursion by using direct subqueries without circular policy joins.
--
-- ROLLBACK CONSIDERATIONS:
-- To cleanly roll back this migration:
--   DROP POLICY IF EXISTS "Students can view their own profile" ON public.students;
--   DROP POLICY IF EXISTS "Students can view their own attendance records" ON public.attendance;
--   DROP POLICY IF EXISTS "Students can view their own strikes" ON public.student_strikes;
--   DROP POLICY IF EXISTS "Students can view their own card actions" ON public.transport_card_actions;
--   DROP POLICY IF EXISTS "Students can view their own phone location" ON public.student_phone_locations;
--   DROP POLICY IF EXISTS "Students can insert their own phone location" ON public.student_phone_locations;
--   DROP POLICY IF EXISTS "Students can update their own phone location" ON public.student_phone_locations;
--   ALTER TABLE public.students DROP COLUMN IF EXISTS auth_user_id;
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Add auth_user_id column to public.students
-- ------------------------------------------------------------
-- Nullable: preserves existing student records (STU001-STU004).
-- UNIQUE: guarantees exactly one Supabase auth user maps to one student.
-- Automatic unique index created by Postgres; no redundant CREATE INDEX.
ALTER TABLE public.students
    ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL;

-- ------------------------------------------------------------
-- 2. Grant Minimum Table-Level Privileges to 'authenticated' Role
-- ------------------------------------------------------------
-- Grants SELECT only; all row filtering is strictly enforced by RLS.
GRANT SELECT ON public.students TO authenticated;
GRANT SELECT ON public.attendance TO authenticated;
GRANT SELECT ON public.student_strikes TO authenticated;
GRANT SELECT ON public.transport_card_actions TO authenticated;

-- Student Phone Location grants for proximity GPS verification
GRANT SELECT, INSERT, UPDATE ON public.student_phone_locations TO authenticated;

-- ------------------------------------------------------------
-- 3. Row Level Security: public.students (Self-Read)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Students can view their own profile" ON public.students;
CREATE POLICY "Students can view their own profile"
ON public.students
FOR SELECT
TO authenticated
USING (
    auth_user_id = (SELECT auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.admin_users au WHERE au.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------
-- 4. Row Level Security: public.attendance (Self-Read History)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Students can view their own attendance records" ON public.attendance;
CREATE POLICY "Students can view their own attendance records"
ON public.attendance
FOR SELECT
TO authenticated
USING (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
    OR EXISTS (
        SELECT 1 FROM public.admin_users au WHERE au.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------
-- 5. Row Level Security: public.student_strikes (Self-Read Strikes)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Students can view their own strikes" ON public.student_strikes;
CREATE POLICY "Students can view their own strikes"
ON public.student_strikes
FOR SELECT
TO authenticated
USING (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
    OR EXISTS (
        SELECT 1 FROM public.admin_users au WHERE au.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------
-- 6. Row Level Security: public.transport_card_actions (Self-Read Actions)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Students can view their own card actions" ON public.transport_card_actions;
CREATE POLICY "Students can view their own card actions"
ON public.transport_card_actions
FOR SELECT
TO authenticated
USING (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
    OR EXISTS (
        SELECT 1 FROM public.admin_users au WHERE au.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------
-- 7. Row Level Security: public.student_phone_locations (Self-Read & Self-Upsert)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Students can view their own phone location" ON public.student_phone_locations;
CREATE POLICY "Students can view their own phone location"
ON public.student_phone_locations
FOR SELECT
TO authenticated
USING (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
    OR EXISTS (
        SELECT 1 FROM public.admin_users au WHERE au.user_id = (SELECT auth.uid())
    )
);

-- Anti-impersonation: student can ONLY insert location matching their linked student_id
DROP POLICY IF EXISTS "Students can insert their own phone location" ON public.student_phone_locations;
CREATE POLICY "Students can insert their own phone location"
ON public.student_phone_locations
FOR INSERT
TO authenticated
WITH CHECK (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
);

-- Anti-impersonation: student can ONLY update their own location and CANNOT modify student_id
DROP POLICY IF EXISTS "Students can update their own phone location" ON public.student_phone_locations;
CREATE POLICY "Students can update their own phone location"
ON public.student_phone_locations
FOR UPDATE
TO authenticated
USING (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    student_id IN (
        SELECT s.id FROM public.students s WHERE s.auth_user_id = (SELECT auth.uid())
    )
);

COMMIT;

