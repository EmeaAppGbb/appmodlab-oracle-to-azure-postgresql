-- ========================================
-- Procedure: Recalculate Tiers (PR_RECALCULATE_TIERS)
-- ========================================
-- Batch recalculation of all member tier statuses

CREATE OR REPLACE PROCEDURE pr_recalculate_tiers(
  p_batch_id       OUT NUMBER,
  p_processed      OUT NUMBER,
  p_upgraded       OUT NUMBER,
  p_downgraded     OUT NUMBER,
  p_unchanged      OUT NUMBER
)
IS
  v_new_tier      VARCHAR2(20);
  v_current_tier  VARCHAR2(20);
  v_qual_miles    NUMBER;
  v_qual_segments NUMBER;
  v_errors        NUMBER := 0;

  -- Tier ranking for comparison
  FUNCTION tier_rank(p_tier VARCHAR2) RETURN NUMBER IS
  BEGIN
    RETURN CASE p_tier
      WHEN 'BLUE'     THEN 1
      WHEN 'SILVER'   THEN 2
      WHEN 'GOLD'     THEN 3
      WHEN 'PLATINUM' THEN 4
      WHEN 'DIAMOND'  THEN 5
      ELSE 0
    END;
  END;

BEGIN
  p_batch_id := pkg_batch_processing.start_batch('TIER_RECALC', 'Scheduled Tier Recalculation');
  p_processed  := 0;
  p_upgraded   := 0;
  p_downgraded := 0;
  p_unchanged  := 0;

  FOR member_rec IN (
    SELECT member_id, tier_status
    FROM members
    WHERE status = 'ACTIVE'
    ORDER BY member_id
  ) LOOP
    BEGIN
      v_current_tier := member_rec.tier_status;

      -- Get qualifying activity
      v_qual_miles := pkg_tier_calculation.get_qualifying_miles(member_rec.member_id);
      v_qual_segments := pkg_tier_calculation.get_qualifying_segments(member_rec.member_id);

      -- Determine new tier
      v_new_tier := 'BLUE';
      FOR tier_rec IN (
        SELECT tier_name, min_miles, min_segments
        FROM tier_rules
        WHERE status = 'ACTIVE'
          AND SYSDATE BETWEEN effective_date AND NVL(expiry_date, SYSDATE + 1)
        ORDER BY min_miles DESC
      ) LOOP
        IF v_qual_miles >= tier_rec.min_miles OR v_qual_segments >= tier_rec.min_segments THEN
          v_new_tier := tier_rec.tier_name;
          EXIT;
        END IF;
      END LOOP;

      -- Apply change if different
      IF v_new_tier != v_current_tier THEN
        UPDATE members SET
          tier_status      = v_new_tier,
          tier_expiry_date = ADD_MONTHS(SYSDATE, 12),
          updated_date     = SYSDATE
        WHERE member_id = member_rec.member_id;

        -- Track direction
        IF tier_rank(v_new_tier) > tier_rank(v_current_tier) THEN
          p_upgraded := p_upgraded + 1;
        ELSE
          p_downgraded := p_downgraded + 1;
        END IF;

        -- Notify member
        pkg_notification.send_notification(
          member_rec.member_id, 'TIER_CHANGE',
          'Your SkyReward Tier Has Changed',
          'Your tier status has been updated from ' || v_current_tier || ' to ' || v_new_tier ||
          '. Qualifying miles: ' || TO_CHAR(v_qual_miles, '999,999') ||
          ', Qualifying segments: ' || v_qual_segments
        );

        pkg_audit.log_change('MEMBERS', 'UPDATE', member_rec.member_id, member_rec.member_id,
          '{"tier_status":"' || v_current_tier || '"}',
          '{"tier_status":"' || v_new_tier || '","qual_miles":' || v_qual_miles || '}');
      ELSE
        p_unchanged := p_unchanged + 1;
      END IF;

      p_processed := p_processed + 1;

      -- Periodic commit
      IF MOD(p_processed, 500) = 0 THEN
        COMMIT;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        v_errors := v_errors + 1;
        DBMS_OUTPUT.PUT_LINE('Error processing member ' || member_rec.member_id || ': ' || SQLERRM);
    END;
  END LOOP;

  pkg_batch_processing.complete_batch(
    p_batch_id, p_processed, p_processed - v_errors, v_errors
  );

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Tier recalculation complete.');
  DBMS_OUTPUT.PUT_LINE('Processed: ' || p_processed || ', Upgraded: ' || p_upgraded ||
                       ', Downgraded: ' || p_downgraded || ', Unchanged: ' || p_unchanged);

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    pkg_batch_processing.complete_batch(p_batch_id, p_processed, 0, p_processed, 'FAILED', SQLERRM);
    RAISE;
END pr_recalculate_tiers;
/
