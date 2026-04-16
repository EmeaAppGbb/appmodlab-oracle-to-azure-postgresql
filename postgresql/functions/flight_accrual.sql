-- ============================================================================
-- Flight Accrual Functions
-- Converted from Oracle PKG_FLIGHT_ACCRUAL package to PostgreSQL PL/pgSQL
-- standalone functions.
--
-- Conversion notes:
--   - Package procedures/functions are now standalone, prefixed with
--     flight_accrual_
--   - %TYPE replaced with explicit PostgreSQL data types
--   - RAISE_APPLICATION_ERROR replaced with RAISE EXCEPTION
--   - NVL replaced with COALESCE
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - seq_xxx.NEXTVAL replaced with nextval('seq_xxx')
--   - ADD_MONTHS replaced with INTERVAL arithmetic
--   - BULK COLLECT / FORALL replaced with standard SQL
--   - COMMIT / ROLLBACK removed (transaction control is external)
--   - Cross-package calls use flattened naming convention
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Package-level constants (exposed as immutable helper function)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_cabin_multiplier(p_cabin_class VARCHAR)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE
AS $$
    SELECT CASE p_cabin_class
        WHEN 'ECONOMY'         THEN 1.0
        WHEN 'PREMIUM_ECONOMY' THEN 1.5
        WHEN 'BUSINESS'        THEN 2.0
        WHEN 'FIRST'           THEN 3.0
        ELSE 1.0
    END;
$$;

-- ---------------------------------------------------------------------------
-- calculate_base_miles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_calculate_base_miles(
    p_distance_miles NUMERIC,
    p_booking_class  VARCHAR,
    p_cabin_class    VARCHAR
)
RETURNS NUMERIC
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    v_multiplier   NUMERIC;
    v_class_factor NUMERIC;
BEGIN
    v_multiplier := CASE p_cabin_class
        WHEN 'ECONOMY'         THEN 1.0
        WHEN 'PREMIUM_ECONOMY' THEN 1.5
        WHEN 'BUSINESS'        THEN 2.0
        WHEN 'FIRST'           THEN 3.0
        ELSE 1.0
    END;

    v_class_factor := CASE
        WHEN p_booking_class IN ('Y','J','F','C')  THEN 1.5
        WHEN p_booking_class IN ('B','M','H')      THEN 1.0
        WHEN p_booking_class IN ('Q','V','W')      THEN 0.75
        WHEN p_booking_class IN ('L','K','N')      THEN 0.5
        ELSE 0.5
    END;

    RETURN GREATEST(ROUND(p_distance_miles * v_multiplier * v_class_factor), 500);
END;
$$;

-- ---------------------------------------------------------------------------
-- calculate_bonus_miles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_calculate_bonus_miles(
    p_base_miles NUMERIC,
    p_member_id  BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_tier      VARCHAR(20);
    v_bonus_pct NUMERIC;
BEGIN
    SELECT tier_status
      INTO v_tier
      FROM members
     WHERE member_id = p_member_id;

    SELECT COALESCE(bonus_miles_pct, 0)
      INTO v_bonus_pct
      FROM tier_rules
     WHERE tier_name = v_tier
       AND status = 'ACTIVE'
       AND CURRENT_TIMESTAMP BETWEEN effective_date
                                 AND COALESCE(expiry_date, CURRENT_TIMESTAMP + INTERVAL '1 day')
     FETCH FIRST 1 ROW ONLY;

    RETURN ROUND(p_base_miles * v_bonus_pct / 100);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
$$;

-- ---------------------------------------------------------------------------
-- record_flight
-- Original Oracle procedure had an OUT parameter p_flight_id; converted to
-- RETURNS BIGINT.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_record_flight(
    p_member_id      BIGINT,
    p_flight_number  VARCHAR,
    p_airline_code   VARCHAR,
    p_departure      VARCHAR,
    p_arrival        VARCHAR,
    p_flight_date    DATE,
    p_booking_class  VARCHAR,
    p_cabin_class    VARCHAR,
    p_distance_miles NUMERIC,
    p_ticket_number  VARCHAR DEFAULT NULL,
    p_pnr_locator   VARCHAR DEFAULT NULL,
    p_fare_amount    NUMERIC DEFAULT NULL,
    p_partner_code   VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_flight_id   BIGINT;
    v_base_miles  NUMERIC;
    v_bonus_miles NUMERIC;
    v_tier_miles  NUMERIC;
    v_total_miles NUMERIC;
BEGIN
    -- Validate that the member is active (cross-package call)
    PERFORM validation_validate_member_active(p_member_id);

    -- Calculate miles
    v_base_miles  := flight_accrual_calculate_base_miles(p_distance_miles, p_booking_class, p_cabin_class);
    v_bonus_miles := flight_accrual_calculate_bonus_miles(v_base_miles, p_member_id);
    v_tier_miles  := v_base_miles;
    v_total_miles := v_base_miles + v_bonus_miles;

    -- Generate new flight id from sequence
    v_flight_id := nextval('seq_flight_id');

    INSERT INTO flights (
        flight_id, member_id, flight_number, airline_code,
        departure, arrival, flight_date, booking_class, cabin_class,
        ticket_number, pnr_locator, distance_miles,
        base_miles, bonus_miles, tier_miles, total_miles,
        fare_amount, accrual_status, partner_code
    ) VALUES (
        v_flight_id, p_member_id, UPPER(p_flight_number), UPPER(p_airline_code),
        UPPER(p_departure), UPPER(p_arrival), p_flight_date, UPPER(p_booking_class), UPPER(p_cabin_class),
        p_ticket_number, UPPER(p_pnr_locator), p_distance_miles,
        v_base_miles, v_bonus_miles, v_tier_miles, v_total_miles,
        p_fare_amount, 'PENDING', UPPER(p_partner_code)
    );

    RETURN v_flight_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- process_pending_accruals
-- Converts BULK COLLECT + FORALL to standard SQL with UPDATE ... RETURNING
-- and a FOR loop for member balance updates.
-- Original OUT parameter p_processed_count becomes RETURNS INTEGER.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_process_pending_accruals(
    p_batch_size INTEGER DEFAULT 1000
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id        BIGINT;
    v_processed_count INTEGER := 0;
    rec               RECORD;
BEGIN
    v_batch_id := nextval('seq_expiry_batch_id');

    -- Update pending flights and capture the affected rows in one statement
    WITH pending AS (
        SELECT flight_id
          FROM flights
         WHERE accrual_status = 'PENDING'
           AND status = 'ACTIVE'
         ORDER BY flight_date
         FETCH FIRST p_batch_size ROWS ONLY
    )
    UPDATE flights f
       SET accrual_status = 'PROCESSED',
           processed_date = CURRENT_TIMESTAMP,
           updated_date   = CURRENT_TIMESTAMP
      FROM pending p
     WHERE f.flight_id = p.flight_id;

    -- Retrieve the just-processed flights to update member balances
    FOR rec IN
        SELECT member_id, total_miles
          FROM flights
         WHERE accrual_status = 'PROCESSED'
           AND processed_date = CURRENT_TIMESTAMP
           AND status = 'ACTIVE'
         ORDER BY flight_date
         FETCH FIRST p_batch_size ROWS ONLY
    LOOP
        PERFORM member_mgmt_update_miles_balance(rec.member_id, rec.total_miles, 'EARN');
        v_processed_count := v_processed_count + 1;
    END LOOP;

    -- If nothing was processed, return early
    IF v_processed_count = 0 THEN
        RETURN 0;
    END IF;

    INSERT INTO batch_processing_log (
        batch_id, batch_type, description,
        start_date, end_date, total_records, processed_records, status
    ) VALUES (
        v_batch_id, 'BULK_ACCRUAL', 'Flight Accrual Processing',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
        v_processed_count, v_processed_count, 'COMPLETED'
    );

    RETURN v_processed_count;
END;
$$;

-- ---------------------------------------------------------------------------
-- reverse_accrual
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_reverse_accrual(
    p_flight_id BIGINT,
    p_reason    VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_id   BIGINT;
    v_total_miles NUMERIC;
    v_status      VARCHAR(20);
BEGIN
    SELECT member_id, total_miles, accrual_status
      INTO STRICT v_member_id, v_total_miles, v_status
      FROM flights
     WHERE flight_id = p_flight_id;

    IF v_status <> 'PROCESSED' THEN
        RAISE EXCEPTION 'Can only reverse processed accruals. Current status: %', v_status;
    END IF;

    UPDATE flights
       SET accrual_status = 'REVERSED',
           updated_date   = CURRENT_TIMESTAMP
     WHERE flight_id = p_flight_id;

    PERFORM member_mgmt_update_miles_balance(v_member_id, -v_total_miles, 'REVERSAL');

    PERFORM audit_log_change(
        'FLIGHTS', 'UPDATE', p_flight_id, v_member_id,
        '{"accrual_status":"PROCESSED"}',
        '{"accrual_status":"REVERSED","reason":"' || p_reason || '"}'
    );
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Flight not found: %', p_flight_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- retroactive_accrual
-- Original Oracle procedure had an OUT parameter p_flight_id; converted to
-- RETURNS BIGINT.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION flight_accrual_retroactive_accrual(
    p_member_id     BIGINT,
    p_flight_number VARCHAR,
    p_flight_date   DATE,
    p_ticket_number VARCHAR
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_dup_count INTEGER;
    v_flight_id BIGINT;
BEGIN
    SELECT COUNT(*)
      INTO v_dup_count
      FROM flights
     WHERE member_id = p_member_id
       AND flight_number = UPPER(p_flight_number)
       AND flight_date = p_flight_date;

    IF v_dup_count > 0 THEN
        RAISE EXCEPTION 'Flight already recorded for this member on this date';
    END IF;

    IF p_flight_date < CURRENT_DATE - INTERVAL '12 months' THEN
        RAISE EXCEPTION 'Retroactive accrual not allowed beyond 12 months';
    END IF;

    v_flight_id := flight_accrual_record_flight(
        p_member_id      := p_member_id,
        p_flight_number  := p_flight_number,
        p_airline_code   := SUBSTR(p_flight_number, 1, 2),
        p_departure      := 'UNK',
        p_arrival        := 'UNK',
        p_flight_date    := p_flight_date,
        p_booking_class  := 'M',
        p_cabin_class    := 'ECONOMY',
        p_distance_miles := 0,
        p_ticket_number  := p_ticket_number
    );

    RETURN v_flight_id;
END;
$$;
