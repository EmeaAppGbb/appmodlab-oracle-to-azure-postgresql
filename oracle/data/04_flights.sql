-- ========================================
-- Flights Data
-- ========================================
-- Sample flight accrual records

DECLARE
  v_member_id NUMBER;
  v_flight_count NUMBER;
  v_origin VARCHAR2(3);
  v_destination VARCHAR2(3);
  v_booking_class VARCHAR2(1);
  v_distance NUMBER;
  v_travel_date DATE;
  TYPE airport_array IS VARRAY(15) OF VARCHAR2(3);
  v_airports airport_array := airport_array('JFK', 'LAX', 'ORD', 'DFW', 'DEN', 'ATL', 'SFO', 'SEA', 'BOS', 'MIA', 'LAS', 'PHX', 'IAH', 'EWR', 'MCO');
BEGIN
  -- Create flights for each member
  FOR member_rec IN (SELECT member_id, tier_status FROM members WHERE status = 'ACTIVE' ORDER BY member_id) LOOP
    -- Vary flight count by tier
    v_flight_count := CASE member_rec.tier_status
                        WHEN 'DIAMOND' THEN TRUNC(DBMS_RANDOM.VALUE(50, 100))
                        WHEN 'PLATINUM' THEN TRUNC(DBMS_RANDOM.VALUE(35, 75))
                        WHEN 'GOLD' THEN TRUNC(DBMS_RANDOM.VALUE(25, 50))
                        WHEN 'SILVER' THEN TRUNC(DBMS_RANDOM.VALUE(10, 25))
                        ELSE TRUNC(DBMS_RANDOM.VALUE(1, 10))
                      END;
    
    FOR i IN 1..v_flight_count LOOP
      -- Random origin and destination
      v_origin := v_airports(TRUNC(DBMS_RANDOM.VALUE(1, 16)));
      v_destination := v_airports(TRUNC(DBMS_RANDOM.VALUE(1, 16)));
      
      -- Ensure different airports
      WHILE v_origin = v_destination LOOP
        v_destination := v_airports(TRUNC(DBMS_RANDOM.VALUE(1, 16)));
      END LOOP;
      
      -- Random booking class (higher tiers fly higher classes more often)
      v_booking_class := CASE 
                          WHEN member_rec.tier_status = 'DIAMOND' AND DBMS_RANDOM.VALUE < 0.4 THEN 'F'
                          WHEN member_rec.tier_status IN ('DIAMOND', 'PLATINUM') AND DBMS_RANDOM.VALUE < 0.5 THEN 'J'
                          WHEN member_rec.tier_status IN ('GOLD', 'PLATINUM') AND DBMS_RANDOM.VALUE < 0.3 THEN 'W'
                          ELSE 'Y'
                        END;
      
      -- Distance based on route
      v_distance := TRUNC(DBMS_RANDOM.VALUE(300, 3000));
      
      -- Travel date in past year
      v_travel_date := TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0, 365));
      
      INSERT INTO flights (
        flight_id, member_id, flight_number, origin, destination,
        travel_date, booking_class, distance_miles,
        miles_earned, qualifying_miles_earned, bonus_miles,
        status, booking_ref
      ) VALUES (
        seq_flight_id.NEXTVAL,
        member_rec.member_id,
        'SR' || TRUNC(DBMS_RANDOM.VALUE(100, 9999)),
        v_origin,
        v_destination,
        v_travel_date,
        v_booking_class,
        v_distance,
        fn_calculate_miles(v_distance, v_booking_class, member_rec.tier_status),
        TRUNC(v_distance * CASE v_booking_class 
                            WHEN 'F' THEN 1.5 
                            WHEN 'J' THEN 1.25 
                            WHEN 'W' THEN 1.0 
                            ELSE 0.5 
                          END),
        TRUNC(v_distance * 0.25), -- Bonus miles
        'POSTED',
        'BK' || TRUNC(DBMS_RANDOM.VALUE(100000, 999999))
      );
    END LOOP;
    
    IF MOD(member_rec.member_id, 1000000) = 0 OR member_rec.member_id = 1000099 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('Processed flights for member ' || member_rec.member_id);
    END IF;
  END LOOP;
  
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Created flight records for all members');
END;
/

SELECT 
  booking_class,
  COUNT(*) AS flight_count,
  TRUNC(AVG(miles_earned)) AS avg_miles,
  TRUNC(SUM(miles_earned)) AS total_miles
FROM flights
GROUP BY booking_class
ORDER BY booking_class;
