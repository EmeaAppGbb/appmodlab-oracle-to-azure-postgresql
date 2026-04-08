-- ========================================
-- Package: Flight Accrual (PKG_FLIGHT_ACCRUAL)
-- ========================================
-- Processes flight miles accrual, calculates base and bonus miles

CREATE OR REPLACE PACKAGE pkg_flight_accrual AS

  -- Custom types
  TYPE t_flight_rec IS RECORD (
    flight_id         flights.flight_id%TYPE,
    member_id         flights.member_id%TYPE,
    flight_number     flights.flight_number%TYPE,
    distance_miles    flights.distance_miles%TYPE,
    booking_class     flights.booking_class%TYPE,
    cabin_class       flights.cabin_class%TYPE,
    base_miles        flights.base_miles%TYPE,
    bonus_miles       flights.bonus_miles%TYPE,
    total_miles       flights.total_miles%TYPE
  );

  -- Constants for cabin multipliers
  c_economy_multiplier      CONSTANT NUMBER := 1.0;
  c_premium_econ_multiplier CONSTANT NUMBER := 1.5;
  c_business_multiplier     CONSTANT NUMBER := 2.0;
  c_first_multiplier        CONSTANT NUMBER := 3.0;

  -- Record a new flight and calculate miles
  PROCEDURE record_flight(
    p_member_id       IN  NUMBER,
    p_flight_number   IN  VARCHAR2,
    p_airline_code    IN  VARCHAR2,
    p_departure       IN  VARCHAR2,
    p_arrival         IN  VARCHAR2,
    p_flight_date     IN  DATE,
    p_booking_class   IN  VARCHAR2,
    p_cabin_class     IN  VARCHAR2,
    p_distance_miles  IN  NUMBER,
    p_ticket_number   IN  VARCHAR2 DEFAULT NULL,
    p_pnr_locator     IN  VARCHAR2 DEFAULT NULL,
    p_fare_amount     IN  NUMBER DEFAULT NULL,
    p_partner_code    IN  VARCHAR2 DEFAULT NULL,
    p_flight_id       OUT NUMBER
  );

  -- Process pending accruals
  PROCEDURE process_pending_accruals(
    p_batch_size      IN  NUMBER DEFAULT 1000,
    p_processed_count OUT NUMBER
  );

  -- Calculate base miles for a booking class
  FUNCTION calculate_base_miles(
    p_distance_miles  IN  NUMBER,
    p_booking_class   IN  VARCHAR2,
    p_cabin_class     IN  VARCHAR2
  ) RETURN NUMBER;

  -- Calculate bonus miles based on tier
  FUNCTION calculate_bonus_miles(
    p_base_miles      IN  NUMBER,
    p_member_id       IN  NUMBER
  ) RETURN NUMBER;

  -- Reverse a flight accrual
  PROCEDURE reverse_accrual(
    p_flight_id       IN  NUMBER,
    p_reason          IN  VARCHAR2
  );

  -- Retroactive accrual for missed flights
  PROCEDURE retroactive_accrual(
    p_member_id       IN  NUMBER,
    p_flight_number   IN  VARCHAR2,
    p_flight_date     IN  DATE,
    p_ticket_number   IN  VARCHAR2,
    p_flight_id       OUT NUMBER
  );

END pkg_flight_accrual;
/

CREATE OR REPLACE PACKAGE BODY pkg_flight_accrual AS

  -- Calculate base miles
  FUNCTION calculate_base_miles(
    p_distance_miles  IN  NUMBER,
    p_booking_class   IN  VARCHAR2,
    p_cabin_class     IN  VARCHAR2
  ) RETURN NUMBER IS
    v_multiplier NUMBER;
    v_class_factor NUMBER;
  BEGIN
    -- Cabin class multiplier
    v_multiplier := CASE p_cabin_class
      WHEN 'ECONOMY'         THEN c_economy_multiplier
      WHEN 'PREMIUM_ECONOMY' THEN c_premium_econ_multiplier
      WHEN 'BUSINESS'        THEN c_business_multiplier
      WHEN 'FIRST'           THEN c_first_multiplier
      ELSE c_economy_multiplier
    END;

    -- Booking class factor (full-fare vs discount)
    v_class_factor := CASE
      WHEN p_booking_class IN ('Y', 'J', 'F', 'C') THEN 1.5   -- Full fare
      WHEN p_booking_class IN ('B', 'M', 'H')      THEN 1.0   -- Standard
      WHEN p_booking_class IN ('Q', 'V', 'W')      THEN 0.75  -- Discount
      WHEN p_booking_class IN ('L', 'K', 'N')      THEN 0.5   -- Deep discount
      ELSE 0.5
    END;

    -- Minimum 500 miles for any flight
    RETURN GREATEST(ROUND(p_distance_miles * v_multiplier * v_class_factor), 500);
  END calculate_base_miles;

  -- Calculate bonus miles
  FUNCTION calculate_bonus_miles(
    p_base_miles      IN  NUMBER,
    p_member_id       IN  NUMBER
  ) RETURN NUMBER IS
    v_tier VARCHAR2(20);
    v_bonus_pct NUMBER;
  BEGIN
    SELECT tier_status INTO v_tier
    FROM members WHERE member_id = p_member_id;

    SELECT NVL(bonus_miles_pct, 0) INTO v_bonus_pct
    FROM tier_rules
    WHERE tier_name = v_tier AND status = 'ACTIVE'
      AND SYSDATE BETWEEN effective_date AND NVL(expiry_date, SYSDATE + 1)
    FETCH FIRST 1 ROW ONLY;

    RETURN ROUND(p_base_miles * v_bonus_pct / 100);

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 0;
  END calculate_bonus_miles;

  -- Record a new flight
  PROCEDURE record_flight(
    p_member_id       IN  NUMBER,
    p_flight_number   IN  VARCHAR2,
    p_airline_code    IN  VARCHAR2,
    p_departure       IN  VARCHAR2,
    p_arrival         IN  VARCHAR2,
    p_flight_date     IN  DATE,
    p_booking_class   IN  VARCHAR2,
    p_cabin_class     IN  VARCHAR2,
    p_distance_miles  IN  NUMBER,
    p_ticket_number   IN  VARCHAR2 DEFAULT NULL,
    p_pnr_locator     IN  VARCHAR2 DEFAULT NULL,
    p_fare_amount     IN  NUMBER DEFAULT NULL,
    p_partner_code    IN  VARCHAR2 DEFAULT NULL,
    p_flight_id       OUT NUMBER
  ) IS
    v_base_miles  NUMBER;
    v_bonus_miles NUMBER;
    v_tier_miles  NUMBER;
    v_total_miles NUMBER;
  BEGIN
    -- Validate member exists and is active
    pkg_validation.validate_member_active(p_member_id);

    -- Calculate miles
    v_base_miles  := calculate_base_miles(p_distance_miles, p_booking_class, p_cabin_class);
    v_bonus_miles := calculate_bonus_miles(v_base_miles, p_member_id);
    v_tier_miles  := v_base_miles; -- Tier miles = base miles
    v_total_miles := v_base_miles + v_bonus_miles;

    p_flight_id := seq_flight_id.NEXTVAL;

    INSERT INTO flights (
      flight_id, member_id, flight_number, airline_code,
      departure_airport, arrival_airport, flight_date,
      booking_class, cabin_class, ticket_number, pnr_locator,
      distance_miles, base_miles, bonus_miles, tier_miles, total_miles,
      fare_amount, accrual_status, partner_code
    ) VALUES (
      p_flight_id, p_member_id, UPPER(p_flight_number), UPPER(p_airline_code),
      UPPER(p_departure), UPPER(p_arrival), p_flight_date,
      UPPER(p_booking_class), UPPER(p_cabin_class), p_ticket_number, UPPER(p_pnr_locator),
      p_distance_miles, v_base_miles, v_bonus_miles, v_tier_miles, v_total_miles,
      p_fare_amount, 'PENDING', UPPER(p_partner_code)
    );

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END record_flight;

  -- Process pending accruals (bulk)
  PROCEDURE process_pending_accruals(
    p_batch_size      IN  NUMBER DEFAULT 1000,
    p_processed_count OUT NUMBER
  ) IS
    TYPE t_flight_ids IS TABLE OF flights.flight_id%TYPE;
    TYPE t_member_ids IS TABLE OF flights.member_id%TYPE;
    TYPE t_total_miles_arr IS TABLE OF flights.total_miles%TYPE;

    v_flight_ids   t_flight_ids;
    v_member_ids   t_member_ids;
    v_total_miles  t_total_miles_arr;
    v_batch_id     NUMBER;
  BEGIN
    p_processed_count := 0;
    v_batch_id := seq_expiry_batch_id.NEXTVAL;

    -- Fetch pending flights
    SELECT flight_id, member_id, total_miles
    BULK COLLECT INTO v_flight_ids, v_member_ids, v_total_miles
    FROM flights
    WHERE accrual_status = 'PENDING'
      AND status = 'ACTIVE'
    ORDER BY flight_date
    FETCH FIRST p_batch_size ROWS ONLY;

    IF v_flight_ids.COUNT = 0 THEN
      RETURN;
    END IF;

    -- Bulk update flights to PROCESSED
    FORALL i IN v_flight_ids.FIRST .. v_flight_ids.LAST
      UPDATE flights
      SET accrual_status = 'PROCESSED',
          processed_date = SYSDATE,
          updated_date   = SYSDATE
      WHERE flight_id = v_flight_ids(i);

    -- Update member balances individually (needs row-level logic)
    FOR i IN v_member_ids.FIRST .. v_member_ids.LAST LOOP
      pkg_member_mgmt.update_miles_balance(v_member_ids(i), v_total_miles(i), 'EARN');
    END LOOP;

    p_processed_count := v_flight_ids.COUNT;

    -- Log batch processing
    INSERT INTO batch_processing_log (
      batch_id, batch_type, batch_name, start_time, end_time,
      records_processed, records_succeeded, status
    ) VALUES (
      v_batch_id, 'BULK_ACCRUAL', 'Flight Accrual Processing',
      SYSDATE, SYSDATE, p_processed_count, p_processed_count, 'COMPLETED'
    );

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END process_pending_accruals;

  -- Reverse a flight accrual
  PROCEDURE reverse_accrual(
    p_flight_id       IN  NUMBER,
    p_reason          IN  VARCHAR2
  ) IS
    v_member_id   NUMBER;
    v_total_miles NUMBER;
    v_status      VARCHAR2(20);
  BEGIN
    SELECT member_id, total_miles, accrual_status
    INTO v_member_id, v_total_miles, v_status
    FROM flights WHERE flight_id = p_flight_id;

    IF v_status != 'PROCESSED' THEN
      RAISE_APPLICATION_ERROR(-20030, 'Can only reverse processed accruals. Current status: ' || v_status);
    END IF;

    UPDATE flights SET
      accrual_status = 'REVERSED',
      updated_date   = SYSDATE
    WHERE flight_id = p_flight_id;

    -- Deduct miles from member
    pkg_member_mgmt.update_miles_balance(v_member_id, -v_total_miles, 'REVERSAL');

    pkg_audit.log_change('FLIGHTS', 'UPDATE', p_flight_id, v_member_id,
      '{"accrual_status":"PROCESSED"}',
      '{"accrual_status":"REVERSED","reason":"' || p_reason || '"}');

    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20031, 'Flight not found: ' || p_flight_id);
  END reverse_accrual;

  -- Retroactive accrual
  PROCEDURE retroactive_accrual(
    p_member_id       IN  NUMBER,
    p_flight_number   IN  VARCHAR2,
    p_flight_date     IN  DATE,
    p_ticket_number   IN  VARCHAR2,
    p_flight_id       OUT NUMBER
  ) IS
    v_dup_count NUMBER;
  BEGIN
    -- Check for duplicate
    SELECT COUNT(*) INTO v_dup_count
    FROM flights
    WHERE member_id = p_member_id
      AND flight_number = UPPER(p_flight_number)
      AND flight_date = p_flight_date;

    IF v_dup_count > 0 THEN
      RAISE_APPLICATION_ERROR(-20032, 'Flight already recorded for this member on this date');
    END IF;

    -- Validate flight date is within 12 months
    IF p_flight_date < ADD_MONTHS(SYSDATE, -12) THEN
      RAISE_APPLICATION_ERROR(-20033, 'Retroactive accrual not allowed beyond 12 months');
    END IF;

    -- Record with default values (would be enriched from flight database in production)
    record_flight(
      p_member_id      => p_member_id,
      p_flight_number  => p_flight_number,
      p_airline_code   => SUBSTR(p_flight_number, 1, 2),
      p_departure      => 'UNK',
      p_arrival        => 'UNK',
      p_flight_date    => p_flight_date,
      p_booking_class  => 'M',
      p_cabin_class    => 'ECONOMY',
      p_distance_miles => 0,
      p_ticket_number  => p_ticket_number,
      p_flight_id      => p_flight_id
    );
  END retroactive_accrual;

END pkg_flight_accrual;
/
