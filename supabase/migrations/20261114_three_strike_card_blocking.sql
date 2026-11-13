-- ============================================================
-- RAKSHA KAWACH — SGT University Transport Safety and Management System
--
-- Migration: Three-Strike Transport Card Blocking & Admin Unblocking
-- Date: 14 November 2026 (Production Preflight Hardened Version)
--
-- Purpose:
-- Authoritative database-backed three-strike RFID transport card blocking:
--   Strike 1: 1/3 — Warning
--   Strike 2: 2/3 — Final Warning
--   Strike 3: 3/3 — Block Transport Card (is_blocked = TRUE)
--
-- Critical Preflight & Edge-Case Rules:
-- 1. Post-Block Violation Handling (4th+ Incidents):
--    When a student already has 3 active strikes and the card is blocked,
--    administrators can still confirm new proxy outcomes ('absent').
--    The incident is preserved as an auditable evidence record (status = 'post_block_violation')
--    without creating a 4th strike, without exceeding the 3-strike cap,
--    and without failing the review transaction.
-- 2. Noncontiguous Slot Allocation:
--    Dynamically allocates the lowest vacant slot in {1, 2, 3}, eliminating
--    unique index slot collision while strictly preserving active count and warning levels.
-- 3. Strict Authenticated Administrator Authorization:
--    Attribution is strictly bound to auth.uid() verified against public.admin_users.
--    No current_user assumptions or impersonation vectors.
-- 4. Strike-Cycle Identifier:
--    Disciplinary cycles partition active vs. historical cleared strikes.
-- 5. Zero Automatic Historical Reconciliation:
--    Pre-existing reviews (e.g. Student Manish STU002) are NOT automatically converted
--    to strikes during migration. A separate audited backfill script is provided.
-- 6. Append-Only Audit Trail:
--    Tamper-prevention trigger blocks UPDATE and DELETE on public.transport_card_actions.
-- 7. Database Write-Boundary Guard:
--    A BEFORE INSERT trigger on public.attendance uses SELECT ... FOR SHARE on public.students
--    to reject attendance creation if is_blocked = TRUE (ERRCODE 'P0001', 'CARD_BLOCKED'),
--    serializing correctly with concurrent administrator strike issuance and unblocking.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Alter public.students: Add Blocking, Strike, and Cycle Columns
-- ------------------------------------------------------------
ALTER TABLE public.students
    ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS active_strikes INTEGER NOT NULL DEFAULT 0
        CHECK (active_strikes >= 0 AND active_strikes <= 3),
    ADD COLUMN IF NOT EXISTS strike_cycle INTEGER NOT NULL DEFAULT 1
        CHECK (strike_cycle >= 1),
    ADD COLUMN IF NOT EXISTS blocked_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS blocked_reason TEXT,
    ADD COLUMN IF NOT EXISTS blocked_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS unblocked_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS unblocked_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS unblock_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_students_is_blocked
    ON public.students(is_blocked);

CREATE INDEX IF NOT EXISTS idx_students_active_strikes
    ON public.students(active_strikes);

CREATE INDEX IF NOT EXISTS idx_students_strike_cycle
    ON public.students(strike_cycle);

-- ------------------------------------------------------------
-- 2. Create Table: public.student_strikes
-- Tracks distinct strike incidents partitioned by strike cycle
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_strikes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    student_id UUID NOT NULL
        REFERENCES public.students(id)
        ON DELETE RESTRICT,

    attendance_id UUID NOT NULL
        REFERENCES public.attendance(id)
        ON DELETE RESTRICT,

    review_id UUID
        REFERENCES public.attendance_reviews(id)
        ON DELETE RESTRICT,

    strike_cycle INTEGER NOT NULL DEFAULT 1
        CHECK (strike_cycle >= 1),

    strike_number INTEGER
        CHECK (strike_number IS NULL OR (strike_number >= 1 AND strike_number <= 3)),

    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'revoked', 'cleared_by_unblock', 'post_block_violation')),

    admin_id UUID NOT NULL
        REFERENCES auth.users(id),

    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES auth.users(id),
    revocation_reason TEXT,

    -- Idempotency: Exactly one strike/violation record per attendance event
    CONSTRAINT uq_student_strikes_attendance UNIQUE (attendance_id),

    -- Active strikes must have a strike slot 1, 2, or 3
    CONSTRAINT chk_active_strike_number CHECK (
        (status = 'active' AND strike_number IS NOT NULL AND strike_number >= 1 AND strike_number <= 3)
        OR (status != 'active')
    )
);

-- Enforce maximum 3 active strikes per cycle at database schema level
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_strike_cycle_slot
    ON public.student_strikes (student_id, strike_cycle, strike_number)
    WHERE (status = 'active');

CREATE INDEX IF NOT EXISTS idx_student_strikes_student_cycle
    ON public.student_strikes(student_id, strike_cycle, status);

CREATE INDEX IF NOT EXISTS idx_student_strikes_created_at
    ON public.student_strikes(created_at DESC);

-- ------------------------------------------------------------
-- 3. Create Table: public.transport_card_actions
-- Append-only audit history of every card block, unblock, and strike action
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transport_card_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    student_id UUID NOT NULL
        REFERENCES public.students(id)
        ON DELETE RESTRICT,

    action TEXT NOT NULL
        CHECK (action IN ('strike_issued', 'strike_revoked', 'card_blocked', 'card_unblocked', 'violation_recorded')),

    admin_id UUID NOT NULL
        REFERENCES auth.users(id),

    reason TEXT NOT NULL
        CHECK (length(btrim(reason)) > 0),

    strike_count_before INTEGER NOT NULL
        CHECK (strike_count_before >= 0 AND strike_count_before <= 3),

    strike_count_after INTEGER NOT NULL
        CHECK (strike_count_after >= 0 AND strike_count_after <= 3),

    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transport_card_actions_student
    ON public.transport_card_actions(student_id, created_at DESC);

-- Trigger enforcing append-only audit trail
CREATE OR REPLACE FUNCTION public.prevent_action_history_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Operation forbidden: transport_card_actions audit trail is strictly append-only. Updates and deletions are prohibited.';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_action_history_tampering ON public.transport_card_actions;
CREATE TRIGGER trg_prevent_action_history_tampering
BEFORE UPDATE OR DELETE ON public.transport_card_actions
FOR EACH ROW EXECUTE FUNCTION public.prevent_action_history_tampering();

-- ------------------------------------------------------------
-- 4. Row Level Security & Privilege Restrictions
-- ------------------------------------------------------------
ALTER TABLE public.student_strikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_card_actions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.student_strikes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.transport_card_actions FROM PUBLIC, anon, authenticated;

-- Verified administrators can read strike and action history
GRANT SELECT ON TABLE public.student_strikes TO authenticated;
GRANT SELECT ON TABLE public.transport_card_actions TO authenticated;

-- No direct client mutations permitted
REVOKE INSERT, UPDATE, DELETE ON TABLE public.student_strikes FROM authenticated, anon, PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.transport_card_actions FROM authenticated, anon, PUBLIC;

DROP POLICY IF EXISTS "Allow verified admins to read student strikes" ON public.student_strikes;
CREATE POLICY "Allow verified admins to read student strikes"
ON public.student_strikes
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users AS au
        WHERE au.user_id = (SELECT auth.uid())
    )
);

DROP POLICY IF EXISTS "Allow verified admins to read transport card actions" ON public.transport_card_actions;
CREATE POLICY "Allow verified admins to read transport card actions"
ON public.transport_card_actions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.admin_users AS au
        WHERE au.user_id = (SELECT auth.uid())
    )
);

-- ------------------------------------------------------------
-- 5. Trigger Function: Disciplinary Strike Management on Review Save
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_attendance_review_strike()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_student_id UUID;
    v_current_cycle INTEGER;
    v_current_strikes INTEGER;
    v_is_already_blocked BOOLEAN;
    v_acting_admin_uid UUID;
    v_existing_strike RECORD;
    v_active_count INTEGER;
    v_next_strike_slot INTEGER;
    v_remaining_strikes INTEGER;
BEGIN
    -- Outcome-Change Gating:
    IF TG_OP = 'UPDATE' AND (OLD.adjudicated_outcome IS NOT DISTINCT FROM NEW.adjudicated_outcome) THEN
        IF NEW.notes IS DISTINCT FROM OLD.notes THEN
            UPDATE public.student_strikes
            SET notes = NEW.notes
            WHERE attendance_id = NEW.attendance_id
              AND notes IS DISTINCT FROM NEW.notes;
        END IF;
        RETURN NEW;
    END IF;

    -- On INSERT: only execute if outcome is 'absent'
    IF TG_OP = 'INSERT' AND (NEW.adjudicated_outcome IS NULL OR NEW.adjudicated_outcome != 'absent') THEN
        RETURN NEW;
    END IF;

    -- Strict Authenticated Administrator Authorization
    v_acting_admin_uid := auth.uid();

    IF v_acting_admin_uid IS NULL THEN
        RAISE EXCEPTION 'Disciplinary action denied: Authenticated administrator session required';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_users WHERE user_id = v_acting_admin_uid
    ) THEN
        RAISE EXCEPTION 'Disciplinary action denied: Acting user % is not an authorized administrator', v_acting_admin_uid;
    END IF;

    -- Identify student from attendance record
    SELECT student_id INTO v_student_id
    FROM public.attendance
    WHERE id = NEW.attendance_id;

    IF v_student_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Lock student row to serialize concurrent updates and retrieve state
    SELECT is_blocked, active_strikes, strike_cycle
    INTO v_is_already_blocked, v_current_strikes, v_current_cycle
    FROM public.students
    WHERE id = v_student_id
    FOR UPDATE;

    IF v_current_cycle IS NULL THEN
        v_current_cycle := 1;
    END IF;

    -- Check if a strike record exists for this attendance event
    SELECT id, strike_cycle, strike_number, status
    INTO v_existing_strike
    FROM public.student_strikes
    WHERE attendance_id = NEW.attendance_id;

    -- ---------------------------------------------------------
    -- Case A: Outcome is Confirmed Proxy ('absent')
    -- ---------------------------------------------------------
    IF NEW.adjudicated_outcome = 'absent' THEN
        IF v_existing_strike.id IS NOT NULL THEN
            -- Historical cycle isolation: Cleared strikes from prior cycles remain frozen
            IF v_existing_strike.strike_cycle < v_current_cycle THEN
                UPDATE public.student_strikes
                SET notes = NEW.notes, review_id = NEW.id
                WHERE id = v_existing_strike.id;
                RETURN NEW;
            END IF;

            -- In current cycle:
            IF v_existing_strike.status = 'active' THEN
                -- Idempotency: Already active strike, sync notes only
                UPDATE public.student_strikes
                SET notes = NEW.notes, review_id = NEW.id
                WHERE id = v_existing_strike.id;
                RETURN NEW;

            ELSIF v_existing_strike.status = 'post_block_violation' THEN
                -- Idempotency: Already recorded post-block violation, sync notes only
                UPDATE public.student_strikes
                SET notes = NEW.notes, review_id = NEW.id
                WHERE id = v_existing_strike.id;
                RETURN NEW;

            ELSIF v_existing_strike.status = 'cleared_by_unblock' THEN
                -- Cleared strike in current cycle: Preserve frozen state
                UPDATE public.student_strikes
                SET notes = NEW.notes, review_id = NEW.id
                WHERE id = v_existing_strike.id;
                RETURN NEW;

            ELSIF v_existing_strike.status = 'revoked' THEN
                -- Reinstating a revoked incident in current cycle
                SELECT slot INTO v_next_strike_slot
                FROM generate_series(1, 3) AS slot
                WHERE slot NOT IN (
                    SELECT strike_number
                    FROM public.student_strikes
                    WHERE student_id = v_student_id
                      AND strike_cycle = v_current_cycle
                      AND status = 'active'
                )
                ORDER BY slot ASC
                LIMIT 1;

                IF v_next_strike_slot IS NOT NULL THEN
                    -- Reinstate into active slot
                    UPDATE public.student_strikes
                    SET status = 'active',
                        strike_number = v_next_strike_slot,
                        notes = NEW.notes,
                        review_id = NEW.id,
                        revoked_at = NULL,
                        revoked_by = NULL,
                        revocation_reason = NULL
                    WHERE id = v_existing_strike.id;

                    SELECT COUNT(*) INTO v_active_count
                    FROM public.student_strikes
                    WHERE student_id = v_student_id AND strike_cycle = v_current_cycle AND status = 'active';

                    UPDATE public.students
                    SET active_strikes = v_active_count,
                        is_blocked = CASE WHEN v_active_count >= 3 THEN TRUE ELSE is_blocked END,
                        blocked_at = CASE WHEN v_active_count >= 3 AND NOT is_blocked THEN now() ELSE blocked_at END,
                        blocked_reason = CASE WHEN v_active_count >= 3 AND NOT is_blocked THEN 'Three confirmed proxy violations (Strike 3/3)' ELSE blocked_reason END,
                        blocked_by = CASE WHEN v_active_count >= 3 AND NOT is_blocked THEN v_acting_admin_uid ELSE blocked_by END
                    WHERE id = v_student_id;

                    INSERT INTO public.transport_card_actions (
                        student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                    ) VALUES (
                        v_student_id,
                        CASE WHEN v_active_count >= 3 THEN 'card_blocked' ELSE 'strike_issued' END,
                        v_acting_admin_uid,
                        'Strike re-activated in slot ' || v_next_strike_slot || ' (cycle ' || v_current_cycle || ') after review re-adjudication to absent',
                        v_current_strikes,
                        v_active_count,
                        jsonb_build_object(
                            'attendance_id', NEW.attendance_id,
                            'review_id', NEW.id,
                            'strike_cycle', v_current_cycle,
                            'strike_number', v_next_strike_slot,
                            'total_active_strikes', v_active_count
                        )
                    );
                    RETURN NEW;
                ELSE
                    -- Student already has 3 active strikes: Reinstate as post_block_violation without exceeding 3 strikes
                    UPDATE public.student_strikes
                    SET status = 'post_block_violation',
                        strike_number = NULL,
                        notes = NEW.notes,
                        review_id = NEW.id,
                        revoked_at = NULL,
                        revoked_by = NULL,
                        revocation_reason = NULL
                    WHERE id = v_existing_strike.id;

                    INSERT INTO public.transport_card_actions (
                        student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                    ) VALUES (
                        v_student_id,
                        'violation_recorded',
                        v_acting_admin_uid,
                        'Confirmed proxy violation re-activated while transport card is already blocked (Disciplinary limit 3/3 maintained)',
                        v_current_strikes,
                        v_current_strikes,
                        jsonb_build_object(
                            'attendance_id', NEW.attendance_id,
                            'review_id', NEW.id,
                            'strike_cycle', v_current_cycle,
                            'incident_type', 'post_block_violation'
                        )
                    );
                    RETURN NEW;
                END IF;
            END IF;
        ELSE
            -- Brand new strike incident:
            SELECT slot INTO v_next_strike_slot
            FROM generate_series(1, 3) AS slot
            WHERE slot NOT IN (
                SELECT strike_number
                FROM public.student_strikes
                WHERE student_id = v_student_id
                  AND strike_cycle = v_current_cycle
                  AND status = 'active'
            )
            ORDER BY slot ASC
            LIMIT 1;

            IF v_next_strike_slot IS NOT NULL THEN
                -- Slots 1, 2, or 3 available: Issue disciplinary strike
                INSERT INTO public.student_strikes (
                    student_id, attendance_id, review_id, strike_cycle, strike_number, status, admin_id, notes
                ) VALUES (
                    v_student_id, NEW.attendance_id, NEW.id, v_current_cycle, v_next_strike_slot, 'active', v_acting_admin_uid, NEW.notes
                );

                SELECT COUNT(*) INTO v_active_count
                FROM public.student_strikes
                WHERE student_id = v_student_id AND strike_cycle = v_current_cycle AND status = 'active';

                UPDATE public.students
                SET active_strikes = v_active_count,
                    is_blocked = CASE WHEN v_active_count >= 3 THEN TRUE ELSE is_blocked END,
                    blocked_at = CASE WHEN v_active_count >= 3 AND NOT is_blocked THEN now() ELSE blocked_at END,
                    blocked_reason = CASE WHEN v_active_count >= 3 AND NOT is_blocked THEN 'Three confirmed proxy violations (Strike 3/3)' ELSE blocked_reason END,
                    blocked_by = CASE WHEN v_active_count >= 3 AND NOT is_blocked THEN v_acting_admin_uid ELSE blocked_by END
                WHERE id = v_student_id;

                INSERT INTO public.transport_card_actions (
                    student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                ) VALUES (
                    v_student_id,
                    CASE WHEN v_active_count >= 3 THEN 'card_blocked' ELSE 'strike_issued' END,
                    v_acting_admin_uid,
                    CASE
                        WHEN v_active_count = 1 THEN '1st confirmed proxy violation (1/3 Warning)'
                        WHEN v_active_count = 2 THEN '2nd confirmed proxy violation (2/3 Final Warning)'
                        ELSE '3rd confirmed proxy violation (3/3 Card Blocked)'
                    END,
                    v_current_strikes,
                    v_active_count,
                    jsonb_build_object(
                        'attendance_id', NEW.attendance_id,
                        'review_id', NEW.id,
                        'strike_cycle', v_current_cycle,
                        'strike_number', v_next_strike_slot,
                        'total_active_strikes', v_active_count
                    )
                );
                RETURN NEW;
            ELSE
                -- CRITICAL EDGE CASE: Student already has 3 active strikes and card is blocked.
                -- Record the confirmed proxy violation as auditable evidence WITHOUT creating a 4th strike
                -- and WITHOUT failing the review transaction.
                INSERT INTO public.student_strikes (
                    student_id, attendance_id, review_id, strike_cycle, strike_number, status, admin_id, notes
                ) VALUES (
                    v_student_id, NEW.attendance_id, NEW.id, v_current_cycle, NULL, 'post_block_violation', v_acting_admin_uid, NEW.notes
                );

                -- Maintain active_strikes = 3 and is_blocked = TRUE
                INSERT INTO public.transport_card_actions (
                    student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                ) VALUES (
                    v_student_id,
                    'violation_recorded',
                    v_acting_admin_uid,
                    'Confirmed proxy violation recorded while transport card is already blocked (Disciplinary limit 3/3 maintained)',
                    v_current_strikes,
                    v_current_strikes,
                    jsonb_build_object(
                        'attendance_id', NEW.attendance_id,
                        'review_id', NEW.id,
                        'strike_cycle', v_current_cycle,
                        'incident_type', 'post_block_violation',
                        'is_blocked', true
                    )
                );
                RETURN NEW;
            END IF;
        END IF;

    -- ---------------------------------------------------------
    -- Case B: Outcome changed AWAY from 'absent' (Reversal / Overturn)
    -- ---------------------------------------------------------
    ELSE
        IF v_existing_strike.id IS NOT NULL THEN
            IF v_existing_strike.strike_cycle < v_current_cycle THEN
                UPDATE public.student_strikes
                SET status = 'revoked',
                    revoked_at = now(),
                    revoked_by = v_acting_admin_uid,
                    revocation_reason = 'Historical cycle ' || v_existing_strike.strike_cycle || ' strike overturned to ' || COALESCE(NEW.adjudicated_outcome, 'pending')
                WHERE id = v_existing_strike.id;
                RETURN NEW;
            END IF;

            -- In current cycle:
            IF v_existing_strike.status = 'active' THEN
                UPDATE public.student_strikes
                SET status = 'revoked',
                    revoked_at = now(),
                    revoked_by = v_acting_admin_uid,
                    revocation_reason = 'Strike overturned by review update to ' || COALESCE(NEW.adjudicated_outcome, 'pending')
                WHERE id = v_existing_strike.id;

                SELECT COUNT(*) INTO v_remaining_strikes
                FROM public.student_strikes
                WHERE student_id = v_student_id AND strike_cycle = v_current_cycle AND status = 'active';

                UPDATE public.students
                SET active_strikes = v_remaining_strikes,
                    is_blocked = CASE WHEN v_remaining_strikes < 3 AND is_blocked THEN FALSE ELSE is_blocked END,
                    unblocked_at = CASE WHEN v_remaining_strikes < 3 AND is_blocked THEN now() ELSE unblocked_at END,
                    unblocked_by = CASE WHEN v_remaining_strikes < 3 AND is_blocked THEN v_acting_admin_uid ELSE unblocked_by END,
                    unblock_reason = CASE WHEN v_remaining_strikes < 3 AND is_blocked THEN 'Automatic unblock: strike revoked below threshold' ELSE unblock_reason END
                WHERE id = v_student_id;

                -- Separate Record 1: Strike Revocation
                INSERT INTO public.transport_card_actions (
                    student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                ) VALUES (
                    v_student_id,
                    'strike_revoked',
                    v_acting_admin_uid,
                    'Strike slot ' || v_existing_strike.strike_number || ' revoked after decision overturned to ' || COALESCE(NEW.adjudicated_outcome, 'pending'),
                    v_current_strikes,
                    v_remaining_strikes,
                    jsonb_build_object(
                        'attendance_id', NEW.attendance_id,
                        'review_id', NEW.id,
                        'revoked_strike_slot', v_existing_strike.strike_number,
                        'strike_cycle', v_current_cycle,
                        'remaining_active_strikes', v_remaining_strikes
                    )
                );

                -- Separate Record 2: Automatic Card Unblock (if student was blocked)
                IF v_is_already_blocked AND v_remaining_strikes < 3 THEN
                    INSERT INTO public.transport_card_actions (
                        student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                    ) VALUES (
                        v_student_id,
                        'card_unblocked',
                        v_acting_admin_uid,
                        'Automatic card unblock: active strikes reduced below threshold (3) following strike revocation',
                        v_remaining_strikes,
                        v_remaining_strikes,
                        jsonb_build_object(
                            'trigger_attendance_id', NEW.attendance_id,
                            'strike_cycle', v_current_cycle,
                            'unblock_type', 'automatic_reversal'
                        )
                    );
                END IF;

            ELSIF v_existing_strike.status = 'post_block_violation' THEN
                -- Reversal of a post-block violation: Does NOT decrease active strikes below 3
                UPDATE public.student_strikes
                SET status = 'revoked',
                    revoked_at = now(),
                    revoked_by = v_acting_admin_uid,
                    revocation_reason = 'Post-block violation overturned to ' || COALESCE(NEW.adjudicated_outcome, 'pending')
                WHERE id = v_existing_strike.id;

                INSERT INTO public.transport_card_actions (
                    student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
                ) VALUES (
                    v_student_id,
                    'strike_revoked',
                    v_acting_admin_uid,
                    'Post-block violation overturned to ' || COALESCE(NEW.adjudicated_outcome, 'pending'),
                    v_current_strikes,
                    v_current_strikes,
                    jsonb_build_object(
                        'attendance_id', NEW.attendance_id,
                        'review_id', NEW.id,
                        'strike_cycle', v_current_cycle,
                        'incident_type', 'post_block_violation'
                    )
                );

            ELSIF v_existing_strike.status = 'cleared_by_unblock' THEN
                UPDATE public.student_strikes
                SET status = 'revoked',
                    revoked_at = now(),
                    revoked_by = v_acting_admin_uid,
                    revocation_reason = 'Cleared strike revoked after later review overturned to ' || COALESCE(NEW.adjudicated_outcome, 'pending')
                WHERE id = v_existing_strike.id;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_attendance_review_strike() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_attendance_reviews_strike ON public.attendance_reviews;
CREATE TRIGGER trg_attendance_reviews_strike
AFTER INSERT OR UPDATE ON public.attendance_reviews
FOR EACH ROW EXECUTE FUNCTION public.handle_attendance_review_strike();

-- ------------------------------------------------------------
-- 6. Secure Administrator RPC: Unblock Transport Card
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unblock_student_transport_card(
    p_student_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_uid UUID;
    v_current_blocked BOOLEAN;
    v_current_strikes INTEGER;
    v_current_cycle INTEGER;
    v_student_name TEXT;
    v_student_code TEXT;
BEGIN
    -- Strict Authenticated Administrator Authorization
    v_admin_uid := auth.uid();

    IF v_admin_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required: User is not signed in';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.admin_users WHERE user_id = v_admin_uid
    ) THEN
        RAISE EXCEPTION 'Access denied: Caller is not a verified administrator';
    END IF;

    -- Validate mandatory unblock explanation
    IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
        RAISE EXCEPTION 'A valid unblock explanation (minimum 5 characters) is mandatory';
    END IF;

    -- Lock student row to prevent concurrent collisions
    SELECT is_blocked, active_strikes, strike_cycle, student_name, student_code
    INTO v_current_blocked, v_current_strikes, v_current_cycle, v_student_name, v_student_code
    FROM public.students
    WHERE id = p_student_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student not found with ID: %', p_student_id;
    END IF;

    IF v_current_cycle IS NULL THEN
        v_current_cycle := 1;
    END IF;

    IF NOT v_current_blocked THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Student transport card is not currently blocked.',
            'student_id', p_student_id,
            'is_blocked', false,
            'active_strikes', v_current_strikes,
            'strike_cycle', v_current_cycle
        );
    END IF;

    -- Mark active strikes and post-block violations in current cycle as cleared_by_unblock
    UPDATE public.student_strikes
    SET status = 'cleared_by_unblock'
    WHERE student_id = p_student_id
      AND strike_cycle = v_current_cycle
      AND status IN ('active', 'post_block_violation');

    -- Advance strike cycle and restore card
    UPDATE public.students
    SET is_blocked = FALSE,
        active_strikes = 0,
        strike_cycle = v_current_cycle + 1,
        unblocked_at = now(),
        unblocked_by = v_admin_uid,
        unblock_reason = btrim(p_reason)
    WHERE id = p_student_id;

    -- Record append-only audit trail
    INSERT INTO public.transport_card_actions (
        student_id, action, admin_id, reason, strike_count_before, strike_count_after, metadata
    ) VALUES (
        p_student_id,
        'card_unblocked',
        v_admin_uid,
        btrim(p_reason),
        v_current_strikes,
        0,
        jsonb_build_object(
            'unblocked_by_name', v_student_name,
            'student_code', v_student_code,
            'cleared_strike_cycle', v_current_cycle,
            'new_strike_cycle', v_current_cycle + 1,
            'unblock_type', 'admin_formal_resolution'
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Transport card unblocked successfully. Active strikes reset to 0.',
        'student_id', p_student_id,
        'student_name', v_student_name,
        'student_code', v_student_code,
        'is_blocked', false,
        'active_strikes', 0,
        'strike_cycle', v_current_cycle + 1,
        'unblocked_at', now()
    );
END;
$$;

REVOKE ALL ON FUNCTION public.unblock_student_transport_card(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unblock_student_transport_card(UUID, TEXT) TO authenticated;

-- ------------------------------------------------------------
-- 7. Database Write-Boundary Guard: Enforce Blocked Card Attendance Rejection
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_attendance_student_not_blocked()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_blocked BOOLEAN;
BEGIN
    -- Retrieve and lock the associated student row using FOR SHARE.
    -- This guarantees serialization against concurrent administrator unblock/block operations:
    -- If an admin transaction holds FOR UPDATE on this student, this query blocks until the
    -- admin transaction commits or rolls back, reading the updated state immediately.
    SELECT is_blocked INTO v_is_blocked
    FROM public.students
    WHERE id = NEW.student_id
    FOR SHARE;

    IF v_is_blocked IS TRUE THEN
        RAISE EXCEPTION 'CARD_BLOCKED: Student transport card is blocked. Attendance insertion rejected.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.check_attendance_student_not_blocked() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_check_attendance_student_not_blocked ON public.attendance;
CREATE TRIGGER trg_check_attendance_student_not_blocked
BEFORE INSERT ON public.attendance
FOR EACH ROW
EXECUTE FUNCTION public.check_attendance_student_not_blocked();

COMMIT;
