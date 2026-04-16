-- ============================================================================
-- Function: Recalculate Tiers (PR_RECALCULATE_TIERS)
-- Converted from Oracle procedure PR_RECALCULATE_TIERS to PostgreSQL PL/pgSQL.
--
-- Conversion notes:
--   - OUT parameters replaced with RETURNS TABLE
--   - Nested FUNCTION tier_rank replaced with inline CASE expression
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - ADD_MONTHS(SYSDATE, 12) replaced with CURRENT_DATE + INTERVAL '12 months'
--   - NVL replaced with COALESCE
--   - pkg_tier_calculation.xxx replaced with tier_calculation_xxx
--   - pkg_notification.send_notification replaced with notification_send_notification
--   - pkg_audit.log_change replaced with audit_log_change
--   - pkg_batch_processing.xxx replaced with batch_processing_xxx
--   - DBMS_OUTPUT.PUT_LINE replaced with RAISE NOTICE
--   - COMMIT / ROLLBACK removed (transaction control is external)
-- ============================================================================

CREATE OR REPLACE FUNCTION pr_recalculate_tiers()
RETURNS TABLE(batch_id BIGINT, processed INT, upgraded INT, downgraded INT, unchanged INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id      BIGINT;
    v_processed     INT := 0;
    v_upgraded      INT := 0;
    v_downgraded    INT := 0;
    v_unchanged     INT := 0;
    v_errors        INT := 0;

    v_new_tier      VARCHAR(20);
    v_current_tier  VARCHAR(20);
    v_qual_miles    NUMERIC;
    v_qual_segments NUMERIC;
    v_new_rank      INT;
    v_current_rank  INT;

    member_rec      RECORD;
    tier_rec        RECORD;
BEGIN
    -- Start batch
    v_batch_id := batch_processing_start_batch('TIER_RECALC', 'Scheduled Tier Recalculation');

    -- Loop over active members
    FOR member_rec IN
        SELECT member_id, tier_status
        FROM   members
        WHERE  status = 'ACTIVE'
        ORDER  BY member_id
    LOOP
        BEGIN
            v_current_tier := member_rec.tier_status;

            -- Get qualifying activity
            v_qual_miles    := tier_calculation_get_qualifying_miles(member_rec.member_id);
            v_qual_segments := tier_calculation_get_qualifying_segments(member_rec.member_id);

            -- Determine new tier (highest qualifying tier first)
            v_new_tier := 'BLUE';
            FOR tier_rec IN
                SELECT tier_name, min_miles, min_segments
                FROM   tier_rules
                WHERE  status = 'ACTIVE'
                  AND  CURRENT_DATE BETWEEN effective_date
                       AND COALESCE(expiry_date, CURRENT_DATE + 1)
                ORDER  BY min_miles DESC
            LOOP
                IF v_qual_miles >= tier_rec.min_miles
                   OR v_qual_segments >= tier_rec.min_segments THEN
                    v_new_tier := tier_rec.tier_name;
                    EXIT;
                END IF;
            END LOOP;

            -- Apply change if tier is different
            IF v_new_tier != v_current_tier THEN
                UPDATE members SET
                    tier_status      = v_new_tier,
                    tier_expiry_date = CURRENT_DATE + INTERVAL '12 months',
                    updated_date     = CURRENT_TIMESTAMP
                WHERE member_id = member_rec.member_id;

                -- Inline tier_rank comparison via CASE
                v_new_rank := CASE v_new_tier
                    WHEN 'BLUE'     THEN 1
                    WHEN 'SILVER'   THEN 2
                    WHEN 'GOLD'     THEN 3
                    WHEN 'PLATINUM' THEN 4
                    WHEN 'DIAMOND'  THEN 5
                    ELSE 0
                END;
                v_current_rank := CASE v_current_tier
                    WHEN 'BLUE'     THEN 1
                    WHEN 'SILVER'   THEN 2
                    WHEN 'GOLD'     THEN 3
                    WHEN 'PLATINUM' THEN 4
                    WHEN 'DIAMOND'  THEN 5
                    ELSE 0
                END;

                IF v_new_rank > v_current_rank THEN
                    v_upgraded := v_upgraded + 1;
                ELSE
                    v_downgraded := v_downgraded + 1;
                END IF;

                -- Notify member
                PERFORM notification_send_notification(
                    member_rec.member_id,
                    'TIER_CHANGE',
                    'Your SkyReward Tier Has Changed',
                    'Your tier status has been updated from ' || v_current_tier ||
                    ' to ' || v_new_tier ||
                    '. Qualifying miles: ' || TO_CHAR(v_qual_miles, '999,999') ||
                    ', Qualifying segments: ' || v_qual_segments
                );

                -- Audit log
                PERFORM audit_log_change(
                    'MEMBERS', 'UPDATE',
                    member_rec.member_id, member_rec.member_id,
                    '{"tier_status":"' || v_current_tier || '"}',
                    '{"tier_status":"' || v_new_tier ||
                    '","qual_miles":' || v_qual_miles || '}'
                );
            ELSE
                v_unchanged := v_unchanged + 1;
            END IF;

            v_processed := v_processed + 1;

        EXCEPTION
            WHEN OTHERS THEN
                v_errors := v_errors + 1;
                RAISE NOTICE 'Error processing member %: %',
                             member_rec.member_id, SQLERRM;
        END;
    END LOOP;

    -- Complete batch
    PERFORM batch_processing_complete_batch(
        v_batch_id, v_processed, v_processed - v_errors, v_errors
    );

    RAISE NOTICE 'Tier recalculation complete.';
    RAISE NOTICE 'Processed: %, Upgraded: %, Downgraded: %, Unchanged: %',
                 v_processed, v_upgraded, v_downgraded, v_unchanged;

    -- Return results
    batch_id  := v_batch_id;
    processed := v_processed;
    upgraded  := v_upgraded;
    downgraded := v_downgraded;
    unchanged := v_unchanged;
    RETURN NEXT;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM batch_processing_complete_batch(
            v_batch_id, v_processed, 0, v_processed, 'FAILED', SQLERRM
        );
        RAISE;
END;
$$;
