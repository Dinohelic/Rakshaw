-- ============================================================
-- RAKSHA KAWACH — SGT University Transport Safety and Management System
--
-- Procedure: Audited Historical Attendance Review Backfill
-- Date: 14 November 2026
--
-- PURPOSE:
-- Safely backfills historical confirmed-proxy reviews (such as Student Manish, STU002)
-- into the three-strike disciplinary ledger.
--
-- SAFETY & AUDIT POLICY:
-- 1. NOT executed automatically during the three-strike migration.
-- 2. Requires explicit administrative and transport committee approval before running.
-- 3. Processes historical reviews strictly in chronological order (scanned_at ASC).
-- 4. Allocates slots 1, 2, and 3 for the first three confirmed proxy incidents.
-- 5. Automatically marks the student as is_blocked = TRUE upon the 3rd incident.
-- 6. Any 4th or subsequent confirmed incidents are recorded as 'post_block_violation'
--    without exceeding the 3-strike cap.
-- 7. Every action is attributed to the approving Super Administrator with full audit metadata.
-- ============================================================

-- Replace with the UUID of the approving Administrator:
-- \set approving_admin_id '11111111-1111-1111-1111-111111111111'

DO $$
DECLARE
    v_admin_id UUID := '11111111-1111-1111-1111-111111111111'::uuid; -- Dean / Super Admin UID
    v_student RECORD;
    v_review RECORD;
    v_current_strikes INTEGER;
    v_active_count INTEGER;
    v_slot INTEGER;
    v_processed_count INTEGER := 0;
BEGIN
    -- Verify approving admin authorization
    IF NOT EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = v_admin_id) THEN
        RAISE EXCEPTION 'Backfill aborted: Approving administrator % is not verified in public.admin_users', v_admin_id;
    END IF;

    RAISE NOTICE '>>> Starting Audited Historical Attendance Review Backfill...';

    -- Loop through each student who has historical confirmed proxy reviews
    FOR v_student IN
        SELECT DISTINCT s.id AS student_id, s.student_name, s.student_code
        FROM public.students s
        JOIN public.attendance a ON a.student_id = s.id
        JOIN public.attendance_reviews r ON r.attendance_id = a.id
        WHERE r.adjudicated_outcome = 'absent'
        ORDER BY s.student_code
    LOOP
        RAISE NOTICE 'Processing student: % (%)', v_student.student_name, v_student.student_code;

        -- Process each review chronologically
        FOR v_review IN
            SELECT r.id AS review_id, r.attendance_id, r.notes, a.scanned_at
            FROM public.attendance_reviews r
            JOIN public.attendance a ON a.id = r.attendance_id
            WHERE a.student_id = v_student.student_id
              AND r.adjudicated_outcome = 'absent'
              AND NOT EXISTS (
                  SELECT 1 FROM public.student_strikes ss WHERE ss.attendance_id = r.attendance_id
              )
            ORDER BY a.scanned_at ASC
        LOOP
            -- Check current active strikes
            SELECT COUNT(*) INTO v_active_count
            FROM public.student_strikes
            WHERE student_id = v_student.student_id
              AND strike_cycle = 1
              AND status = 'active';

            IF v_active_count < 3 THEN
                v_slot := v_active_count + 1;

                INSERT INTO public.student_strikes (
                    student_id, attendance_id, review_id, strike_cycle, strike_number, status, admin_id, notes, created_at
                ) VALUES (
                    v_student.student_id, v_review.attendance_id, v_review.review_id, 1, v_slot, 'active', v_admin_id,
                    '[Backfill] ' || COALESCE(v_review.notes, 'Historical confirmed proxy boarding'),
                    v_review.scanned_at
                );

                UPDATE public.students
                SET active_strikes = v_slot,
                    is_blocked = CASE WHEN v_slot >= 3 THEN TRUE ELSE is_blocked END,
                    blocked_at = CASE WHEN v_slot >= 3 AND NOT is_blocked THEN now() ELSE blocked_at END,
                    blocked_reason = CASE WHEN v_slot >= 3 AND NOT is_blocked THEN 'Three confirmed proxy violations (Strike 3/3 — Audited Backfill)' ELSE blocked_reason END,
                    blocked_by = CASE WHEN v_slot >= 3 AND NOT is_blocked THEN v_admin_id ELSE blocked_by END
                WHERE id = v_student.student_id;

                INSERT INTO public.transport_card_actions (
                    student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata, created_at
                ) VALUES (
                    v_student.student_id,
                    CASE WHEN v_slot >= 3 THEN 'card_blocked' ELSE 'strike_issued' END,
                    v_admin_id,
                    CASE
                        WHEN v_slot = 1 THEN '1st confirmed proxy violation (1/3 Warning — Historical Backfill)'
                        WHEN v_slot = 2 THEN '2nd confirmed proxy violation (2/3 Final Warning — Historical Backfill)'
                        ELSE '3rd confirmed proxy violation (3/3 Card Blocked — Historical Backfill)'
                    END,
                    v_active_count,
                    v_slot,
                    jsonb_build_object(
                        'attendance_id', v_review.attendance_id,
                        'review_id', v_review.review_id,
                        'strike_cycle', 1,
                        'strike_number', v_slot,
                        'backfill', true
                    ),
                    v_review.scanned_at
                );
            ELSE
                -- Already at 3 strikes: Record as post-block violation
                INSERT INTO public.student_strikes (
                    student_id, attendance_id, review_id, strike_cycle, strike_number, status, admin_id, notes, created_at
                ) VALUES (
                    v_student.student_id, v_review.attendance_id, v_review.review_id, 1, NULL, 'post_block_violation', v_admin_id,
                    '[Backfill] ' || COALESCE(v_review.notes, 'Historical violation after card block'),
                    v_review.scanned_at
                );

                INSERT INTO public.transport_card_actions (
                    student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata, created_at
                ) VALUES (
                    v_student.student_id,
                    'violation_recorded',
                    v_admin_id,
                    'Historical confirmed proxy violation recorded after block threshold (3/3 limit maintained)',
                    3,
                    3,
                    jsonb_build_object(
                        'attendance_id', v_review.attendance_id,
                        'review_id', v_review.review_id,
                        'strike_cycle', 1,
                        'incident_type', 'post_block_violation',
                        'backfill', true
                    ),
                    v_review.scanned_at
                );
            END IF;

            v_processed_count := v_processed_count + 1;
        END LOOP;
    END LOOP;

    RAISE NOTICE '>>> Audited Historical Backfill Completed: % reviews reconciled.', v_processed_count;
END $$;

