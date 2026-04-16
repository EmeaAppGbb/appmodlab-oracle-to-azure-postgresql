-- ============================================================================
-- Trigger: Flight Validation (TRG_FLIGHT_VALIDATION)
-- Converted from Oracle trigger TRG_FLIGHT_VALIDATION to PostgreSQL PL/pgSQL.
--
-- Conversion notes:
--   - Oracle standalone trigger split into trigger function + CREATE TRIGGER
--   - :NEW replaced with NEW
--   - INSERTING replaced with TG_OP = 'INSERT'
--   - RAISE_APPLICATION_ERROR replaced with RAISE EXCEPTION
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - ADD_MONTHS(SYSDATE, -24) replaced with CURRENT_DATE - INTERVAL '24 months'
--   - BEFORE trigger must RETURN NEW
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_flight_validation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_status VARCHAR(20);
    v_dup_count     INT;
BEGIN
    -- Validate member exists and is active
    BEGIN
        SELECT status INTO STRICT v_member_status
        FROM   members
        WHERE  member_id = NEW.member_id;

        IF v_member_status != 'ACTIVE' THEN
            RAISE EXCEPTION 'Cannot record flight for inactive member. Status: %',
                            v_member_status;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE EXCEPTION 'Member not found: %', NEW.member_id;
    END;

    -- Validate flight date is not in the future
    IF NEW.flight_date > CURRENT_DATE + 1 THEN
        RAISE EXCEPTION 'Flight date cannot be in the future: %',
                        TO_CHAR(NEW.flight_date, 'YYYY-MM-DD');
    END IF;

    -- Validate flight date is not too old (24 months)
    IF NEW.flight_date < CURRENT_DATE - INTERVAL '24 months' THEN
        RAISE EXCEPTION 'Flight date is older than 24 months and cannot be processed';
    END IF;

    -- Validate departure and arrival are different
    IF NEW.departure_airport = NEW.arrival_airport THEN
        RAISE EXCEPTION 'Departure and arrival airports must be different';
    END IF;

    -- Validate distance is reasonable (max 12,000 miles for any single flight)
    IF NEW.distance_miles > 12000 THEN
        RAISE EXCEPTION 'Distance exceeds maximum allowable: %', NEW.distance_miles;
    END IF;

    -- Check for duplicate flights on INSERT
    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*) INTO v_dup_count
        FROM   flights
        WHERE  member_id = NEW.member_id
          AND  flight_number = NEW.flight_number
          AND  flight_date = NEW.flight_date
          AND  departure_airport = NEW.departure_airport
          AND  status = 'ACTIVE';

        IF v_dup_count > 0 THEN
            RAISE EXCEPTION 'Duplicate flight detected for this member, flight number, and date';
        END IF;
    END IF;

    -- Normalize data
    NEW.flight_number     := UPPER(NEW.flight_number);
    NEW.airline_code      := UPPER(NEW.airline_code);
    NEW.departure_airport := UPPER(NEW.departure_airport);
    NEW.arrival_airport   := UPPER(NEW.arrival_airport);
    NEW.booking_class     := UPPER(NEW.booking_class);
    NEW.cabin_class       := UPPER(NEW.cabin_class);

    -- Ensure minimum miles
    IF NEW.total_miles < 500 AND NEW.accrual_status = 'PENDING' THEN
        NEW.total_miles := 500;
        NEW.base_miles  := 500;
    END IF;

    -- Set updated date
    NEW.updated_date := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER trg_flight_validation
    BEFORE INSERT OR UPDATE ON flights
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_flight_validation();
