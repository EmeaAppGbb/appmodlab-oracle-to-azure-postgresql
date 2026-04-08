-- ========================================
-- Trigger: Flight Validation (TRG_FLIGHT_VALIDATION)
-- ========================================
-- Validates flight data before insert, enforces business rules

CREATE OR REPLACE TRIGGER trg_flight_validation
  BEFORE INSERT OR UPDATE ON flights
  FOR EACH ROW
DECLARE
  v_member_status VARCHAR2(20);
  v_dup_count     NUMBER;
BEGIN
  -- Validate member exists and is active
  BEGIN
    SELECT status INTO v_member_status
    FROM members WHERE member_id = :NEW.member_id;

    IF v_member_status != 'ACTIVE' THEN
      RAISE_APPLICATION_ERROR(-20200, 'Cannot record flight for inactive member. Status: ' || v_member_status);
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20201, 'Member not found: ' || :NEW.member_id);
  END;

  -- Validate flight date is not in the future
  IF :NEW.flight_date > SYSDATE + 1 THEN
    RAISE_APPLICATION_ERROR(-20202, 'Flight date cannot be in the future: ' || TO_CHAR(:NEW.flight_date, 'YYYY-MM-DD'));
  END IF;

  -- Validate flight date is not too old (24 months)
  IF :NEW.flight_date < ADD_MONTHS(SYSDATE, -24) THEN
    RAISE_APPLICATION_ERROR(-20203, 'Flight date is older than 24 months and cannot be processed');
  END IF;

  -- Validate departure and arrival are different
  IF :NEW.departure_airport = :NEW.arrival_airport THEN
    RAISE_APPLICATION_ERROR(-20204, 'Departure and arrival airports must be different');
  END IF;

  -- Validate distance is reasonable (max 12,000 miles for any single flight)
  IF :NEW.distance_miles > 12000 THEN
    RAISE_APPLICATION_ERROR(-20205, 'Distance exceeds maximum allowable: ' || :NEW.distance_miles);
  END IF;

  -- Check for duplicate flights on INSERT
  IF INSERTING THEN
    SELECT COUNT(*) INTO v_dup_count
    FROM flights
    WHERE member_id = :NEW.member_id
      AND flight_number = :NEW.flight_number
      AND flight_date = :NEW.flight_date
      AND departure_airport = :NEW.departure_airport
      AND status = 'ACTIVE';

    IF v_dup_count > 0 THEN
      RAISE_APPLICATION_ERROR(-20206, 'Duplicate flight detected for this member, flight number, and date');
    END IF;
  END IF;

  -- Normalize data
  :NEW.flight_number     := UPPER(:NEW.flight_number);
  :NEW.airline_code      := UPPER(:NEW.airline_code);
  :NEW.departure_airport := UPPER(:NEW.departure_airport);
  :NEW.arrival_airport   := UPPER(:NEW.arrival_airport);
  :NEW.booking_class     := UPPER(:NEW.booking_class);
  :NEW.cabin_class       := UPPER(:NEW.cabin_class);

  -- Ensure minimum miles
  IF :NEW.total_miles < 500 AND :NEW.accrual_status = 'PENDING' THEN
    :NEW.total_miles := 500;
    :NEW.base_miles  := 500;
  END IF;

  -- Set updated date
  :NEW.updated_date := SYSDATE;

END trg_flight_validation;
/
