-- ========================================
-- Package: Tier Calculation (PKG_TIER_CALCULATION)
-- ========================================
-- Evaluates and updates member tier status based on qualifying activity

CREATE OR REPLACE PACKAGE pkg_tier_calculation AS

  -- Tier hierarchy (Oracle hierarchical query support)
  TYPE t_tier_info IS RECORD (
    tier_name         tier_rules.tier_name%TYPE,
    min_miles         tier_rules.min_miles%TYPE,
    min_segments      tier_rules.min_segments%TYPE,
    miles_multiplier  tier_rules.miles_multiplier%TYPE,
    bonus_miles_pct   tier_rules.bonus_miles_pct%TYPE
  );

  TYPE t_tier_tab IS TABLE OF t_tier_info INDEX BY PLS_INTEGER;

  -- Evaluate a single member's tier
  FUNCTION evaluate_tier(p_member_id IN NUMBER) RETURN VARCHAR2;

  -- Recalculate tier for a single member and apply changes
  PROCEDURE recalculate_member_tier(
    p_member_id   IN  NUMBER,
    p_new_tier    OUT VARCHAR2,
    p_changed     OUT BOOLEAN
  );

  -- Batch recalculate all member tiers
  PROCEDURE recalculate_all_tiers(
    p_processed_count OUT NUMBER,
    p_changed_count   OUT NUMBER
  );

  -- Get qualifying miles for a period
  FUNCTION get_qualifying_miles(
    p_member_id   IN  NUMBER,
    p_months_back IN  NUMBER DEFAULT 12
  ) RETURN NUMBER;

  -- Get qualifying segments for a period
  FUNCTION get_qualifying_segments(
    p_member_id   IN  NUMBER,
    p_months_back IN  NUMBER DEFAULT 12
  ) RETURN NUMBER;

  -- Get tier benefits using CONNECT BY hierarchy
  FUNCTION get_tier_hierarchy RETURN t_tier_tab;

  -- Check if member qualifies for tier upgrade
  FUNCTION check_upgrade_eligibility(p_member_id IN NUMBER) RETURN VARCHAR2;

END pkg_tier_calculation;
/

CREATE OR REPLACE PACKAGE BODY pkg_tier_calculation AS

  -- Get qualifying miles
  FUNCTION get_qualifying_miles(
    p_member_id   IN  NUMBER,
    p_months_back IN  NUMBER DEFAULT 12
  ) RETURN NUMBER IS
    v_miles NUMBER;
  BEGIN
    SELECT NVL(SUM(tier_miles), 0) INTO v_miles
    FROM flights
    WHERE member_id = p_member_id
      AND accrual_status = 'PROCESSED'
      AND flight_date >= ADD_MONTHS(TRUNC(SYSDATE), -p_months_back);

    RETURN v_miles;
  END get_qualifying_miles;

  -- Get qualifying segments
  FUNCTION get_qualifying_segments(
    p_member_id   IN  NUMBER,
    p_months_back IN  NUMBER DEFAULT 12
  ) RETURN NUMBER IS
    v_segments NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_segments
    FROM flights
    WHERE member_id = p_member_id
      AND accrual_status = 'PROCESSED'
      AND flight_date >= ADD_MONTHS(TRUNC(SYSDATE), -p_months_back);

    RETURN v_segments;
  END get_qualifying_segments;

  -- Evaluate tier (determines what tier a member qualifies for)
  FUNCTION evaluate_tier(p_member_id IN NUMBER) RETURN VARCHAR2 IS
    v_qual_miles    NUMBER;
    v_qual_segments NUMBER;
    v_new_tier      VARCHAR2(20) := 'BLUE';
  BEGIN
    v_qual_miles    := get_qualifying_miles(p_member_id);
    v_qual_segments := get_qualifying_segments(p_member_id);

    -- Check tiers from highest to lowest using Oracle hierarchical ordering
    FOR rec IN (
      SELECT tier_name, min_miles, min_segments
      FROM tier_rules
      WHERE status = 'ACTIVE'
        AND SYSDATE BETWEEN effective_date AND NVL(expiry_date, SYSDATE + 1)
      ORDER BY min_miles DESC
    ) LOOP
      IF v_qual_miles >= rec.min_miles OR v_qual_segments >= rec.min_segments THEN
        v_new_tier := rec.tier_name;
        EXIT;
      END IF;
    END LOOP;

    RETURN v_new_tier;
  END evaluate_tier;

  -- Recalculate single member tier
  PROCEDURE recalculate_member_tier(
    p_member_id   IN  NUMBER,
    p_new_tier    OUT VARCHAR2,
    p_changed     OUT BOOLEAN
  ) IS
    v_current_tier VARCHAR2(20);
  BEGIN
    SELECT tier_status INTO v_current_tier
    FROM members WHERE member_id = p_member_id;

    p_new_tier := evaluate_tier(p_member_id);
    p_changed := (v_current_tier != p_new_tier);

    IF p_changed THEN
      UPDATE members SET
        tier_status      = p_new_tier,
        tier_expiry_date = ADD_MONTHS(SYSDATE, 12),
        updated_date     = SYSDATE
      WHERE member_id = p_member_id;

      -- Send tier change notification
      pkg_notification.send_notification(
        p_member_id, 'TIER_CHANGE',
        'Tier Status Update',
        'Congratulations! Your SkyReward tier has been updated from ' ||
        v_current_tier || ' to ' || p_new_tier
      );

      pkg_audit.log_change('MEMBERS', 'UPDATE', p_member_id, p_member_id,
        '{"tier_status":"' || v_current_tier || '"}',
        '{"tier_status":"' || p_new_tier || '"}');

      COMMIT;
    END IF;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Member not found: ' || p_member_id);
  END recalculate_member_tier;

  -- Batch recalculate all tiers
  PROCEDURE recalculate_all_tiers(
    p_processed_count OUT NUMBER,
    p_changed_count   OUT NUMBER
  ) IS
    v_new_tier  VARCHAR2(20);
    v_changed   BOOLEAN;
    v_batch_id  NUMBER;
  BEGIN
    p_processed_count := 0;
    p_changed_count   := 0;
    v_batch_id := seq_expiry_batch_id.NEXTVAL;

    INSERT INTO batch_processing_log (
      batch_id, batch_type, batch_name, start_time, status
    ) VALUES (
      v_batch_id, 'TIER_RECALC', 'Nightly Tier Recalculation', SYSDATE, 'RUNNING'
    );
    COMMIT;

    FOR rec IN (
      SELECT member_id FROM members
      WHERE status = 'ACTIVE'
      ORDER BY member_id
    ) LOOP
      BEGIN
        recalculate_member_tier(rec.member_id, v_new_tier, v_changed);
        p_processed_count := p_processed_count + 1;
        IF v_changed THEN
          p_changed_count := p_changed_count + 1;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          -- Log error but continue processing
          DBMS_OUTPUT.PUT_LINE('Error processing member ' || rec.member_id || ': ' || SQLERRM);
      END;
    END LOOP;

    UPDATE batch_processing_log SET
      end_time          = SYSDATE,
      records_processed = p_processed_count,
      records_succeeded = p_processed_count,
      records_failed    = 0,
      status            = 'COMPLETED'
    WHERE batch_id = v_batch_id;

    COMMIT;
  END recalculate_all_tiers;

  -- Get tier hierarchy using CONNECT BY
  FUNCTION get_tier_hierarchy RETURN t_tier_tab IS
    v_tab t_tier_tab;
    v_idx PLS_INTEGER := 0;
  BEGIN
    FOR rec IN (
      SELECT tier_name, min_miles, min_segments, miles_multiplier, bonus_miles_pct,
             LEVEL AS tier_level
      FROM tier_rules
      WHERE status = 'ACTIVE'
      START WITH min_miles = 0
      CONNECT BY PRIOR min_miles < min_miles
      ORDER BY LEVEL
    ) LOOP
      v_idx := v_idx + 1;
      v_tab(v_idx).tier_name        := rec.tier_name;
      v_tab(v_idx).min_miles        := rec.min_miles;
      v_tab(v_idx).min_segments     := rec.min_segments;
      v_tab(v_idx).miles_multiplier := rec.miles_multiplier;
      v_tab(v_idx).bonus_miles_pct  := rec.bonus_miles_pct;
    END LOOP;

    RETURN v_tab;
  END get_tier_hierarchy;

  -- Check upgrade eligibility
  FUNCTION check_upgrade_eligibility(p_member_id IN NUMBER) RETURN VARCHAR2 IS
    v_current_tier VARCHAR2(20);
    v_potential     VARCHAR2(20);
  BEGIN
    SELECT tier_status INTO v_current_tier
    FROM members WHERE member_id = p_member_id;

    v_potential := evaluate_tier(p_member_id);

    IF v_potential = v_current_tier THEN
      RETURN 'NO_CHANGE';
    ELSIF v_potential > v_current_tier THEN
      RETURN 'UPGRADE_TO_' || v_potential;
    ELSE
      RETURN 'DOWNGRADE_TO_' || v_potential;
    END IF;
  END check_upgrade_eligibility;

END pkg_tier_calculation;
/
