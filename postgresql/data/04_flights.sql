-- ========================================
-- Flights Data (PostgreSQL)
-- ========================================
-- Converted from Oracle PL/SQL:
--   VARRAY          -> PostgreSQL array
--   DBMS_RANDOM     -> random()
--   WHILE/END LOOP  -> same syntax in PL/pgSQL
--   TRUNC(SYSDATE)  -> CURRENT_DATE
--   fn_calculate_miles() -> fn_calculate_miles() (already migrated)
--   seq.NEXTVAL     -> nextval('seq')
-- Column mapping: origin->departure_airport, destination->arrival_airport,
--   travel_date->flight_date, miles_earned->total_miles,
--   qualifying_miles_earned->tier_miles, booking_ref->pnr_locator,
--   status->accrual_status, added airline_code, cabin_class, base_miles

DO $$
DECLARE
  v_flight_count INTEGER;
  v_origin VARCHAR(3);
  v_destination VARCHAR(3);
  v_booking_class VARCHAR(1);
  v_cabin_class VARCHAR(20);
  v_distance INTEGER;
  v_travel_date DATE;
  v_base_miles INTEGER;
  v_bonus_miles INTEGER;
  v_tier_miles INTEGER;
  v_total_miles INTEGER;
  v_airports TEXT[] := ARRAY['JFK','LAX','ORD','DFW','DEN','ATL','SFO','SEA','BOS','MIA','LAS','PHX','IAH','EWR','MCO'];
  member_rec RECORD;
BEGIN
  FOR member_rec IN (SELECT member_id, tier_status FROM members WHERE status = 'ACTIVE' ORDER BY member_id) LOOP
    v_flight_count := CASE member_rec.tier_status
                        WHEN 'DIAMOND'  THEN floor(random() * 50 + 50)::int
                        WHEN 'PLATINUM' THEN floor(random() * 40 + 35)::int
                        WHEN 'GOLD'     THEN floor(random() * 25 + 25)::int
                        WHEN 'SILVER'   THEN floor(random() * 15 + 10)::int
                        ELSE floor(random() * 9 + 1)::int
                      END;

    FOR i IN 1..v_flight_count LOOP
      v_origin := v_airports[floor(random() * 15 + 1)::int];
      v_destination := v_airports[floor(random() * 15 + 1)::int];

      WHILE v_origin = v_destination LOOP
        v_destination := v_airports[floor(random() * 15 + 1)::int];
      END LOOP;

      -- Booking class and cabin class mapping
      v_booking_class := CASE
                           WHEN member_rec.tier_status = 'DIAMOND' AND random() < 0.4 THEN 'F'
                           WHEN member_rec.tier_status IN ('DIAMOND','PLATINUM') AND random() < 0.5 THEN 'J'
                           WHEN member_rec.tier_status IN ('GOLD','PLATINUM') AND random() < 0.3 THEN 'W'
                           ELSE 'Y'
                         END;

      v_cabin_class := CASE v_booking_class
                         WHEN 'F' THEN 'FIRST'
                         WHEN 'J' THEN 'BUSINESS'
                         WHEN 'W' THEN 'PREMIUM_ECONOMY'
                         ELSE 'ECONOMY'
                       END;

      v_distance := floor(random() * 2700 + 300)::int;
      v_travel_date := CURRENT_DATE - floor(random() * 365)::int;

      -- Calculate miles using the migrated function
      v_total_miles := fn_calculate_miles(v_distance, v_booking_class, v_cabin_class, member_rec.tier_status);
      v_base_miles := GREATEST(round(v_distance * CASE v_booking_class
                                                    WHEN 'F' THEN 1.5
                                                    WHEN 'J' THEN 1.25
                                                    WHEN 'W' THEN 1.0
                                                    ELSE 0.5
                                                  END)::int, 500);
      v_bonus_miles := floor(v_distance * 0.25)::int;
      v_tier_miles := floor(v_distance * CASE v_booking_class
                                           WHEN 'F' THEN 1.5
                                           WHEN 'J' THEN 1.25
                                           WHEN 'W' THEN 1.0
                                           ELSE 0.5
                                         END)::int;

      INSERT INTO flights (
        flight_id, member_id, flight_number, airline_code,
        departure_airport, arrival_airport, flight_date,
        booking_class, cabin_class, distance_miles,
        base_miles, bonus_miles, tier_miles, total_miles,
        accrual_status, pnr_locator
      ) VALUES (
        nextval('seq_flight_id'),
        member_rec.member_id,
        'SR' || floor(random() * 9899 + 100)::int,
        'SR',
        v_origin,
        v_destination,
        v_travel_date,
        v_booking_class,
        v_cabin_class,
        v_distance,
        v_base_miles,
        v_bonus_miles,
        v_tier_miles,
        v_total_miles,
        'PROCESSED',
        'BK' || floor(random() * 899999 + 100000)::int
      );
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Created flight records for all members';
END $$;

SELECT
  booking_class,
  COUNT(*) AS flight_count,
  floor(AVG(total_miles)) AS avg_miles,
  floor(SUM(total_miles)) AS total_miles
FROM flights
GROUP BY booking_class
ORDER BY booking_class;
