-- Front-end demo seed: creates Canadian/US airports, routes, 60 days of flights,
-- and seat layouts aligned with the UI map (FIRST: A/D/G/J, BUSINESS: A/D/G/J,
-- ECONOMY: ABC/DEF/GHJ). Safe to re-run; it removes prior flights with prefix FD*.
SET DEFINE OFF;
SET SERVEROUTPUT ON;

PROMPT Cleaning previous FD* demo data...
BEGIN
  DELETE FROM ticket_audit WHERE ticket_id IN (
    SELECT t.ticket_id
    FROM ticket t
    JOIN flight f ON f.flight_id = t.flight_id
    WHERE f.flight_number LIKE 'FD%'
  );

  DELETE FROM ticket
  WHERE flight_id IN (SELECT flight_id FROM flight WHERE flight_number LIKE 'FD%');

  DELETE FROM booking
  WHERE flight_id IN (SELECT flight_id FROM flight WHERE flight_number LIKE 'FD%');

  DELETE FROM seat_layout
  WHERE flight_id IN (SELECT flight_id FROM flight WHERE flight_number LIKE 'FD%');

  DELETE FROM flight WHERE flight_number LIKE 'FD%';
END;
/

PROMPT Inserting airports...
BEGIN
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('YYZ', 'Toronto Pearson', 'Toronto', 'Canada'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('YVR', 'Vancouver Intl', 'Vancouver', 'Canada'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('YUL', 'Montreal Trudeau', 'Montreal', 'Canada'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('LAX', 'Los Angeles Intl', 'Los Angeles', 'USA'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('JFK', 'John F. Kennedy', 'New York', 'USA'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
END;
/

PROMPT Inserting aircraft...
DECLARE
  v_ac1 NUMBER;
  v_ac2 NUMBER;
BEGIN
  BEGIN
    INSERT INTO aircraft(model, tail_number, total_seats) VALUES ('Boeing 737-8', 'FD-001', 174)
    RETURNING aircraft_id INTO v_ac1;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT aircraft_id INTO v_ac1 FROM aircraft WHERE tail_number = 'FD-001';
  END;

  BEGIN
    INSERT INTO aircraft(model, tail_number, total_seats) VALUES ('Airbus A321', 'FD-002', 185)
    RETURNING aircraft_id INTO v_ac2;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT aircraft_id INTO v_ac2 FROM aircraft WHERE tail_number = 'FD-002';
  END;
END;
/

PROMPT Inserting routes (YYZ<->YVR/YUL/LAX/JFK)...
BEGIN
  -- YYZ -> YVR / return
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 3358, 320, 980, 1600
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'YYZ' AND arr.airport_code = 'YVR';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 3358, 320, 980, 1600
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'YVR' AND arr.airport_code = 'YYZ';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  -- YYZ -> YUL / return
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 500, 180, 620, 950
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'YYZ' AND arr.airport_code = 'YUL';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 500, 180, 620, 950
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'YUL' AND arr.airport_code = 'YYZ';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  -- YYZ -> LAX / return
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 3492, 340, 1020, 1700
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'YYZ' AND arr.airport_code = 'LAX';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 3492, 340, 1020, 1700
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'LAX' AND arr.airport_code = 'YYZ';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  -- YYZ -> JFK / return
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 589, 200, 680, 1050
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'YYZ' AND arr.airport_code = 'JFK';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/
BEGIN
  INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
  SELECT dep.airport_id, arr.airport_id, 589, 200, 680, 1050
  FROM airport dep, airport arr
  WHERE dep.airport_code = 'JFK' AND arr.airport_code = 'YYZ';
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
/

PROMPT Inserting flights for 60 days (morning/afternoon per route)...
DECLARE
  v_start DATE := TRUNC(SYSDATE);
  v_route_id route.route_id%TYPE;
  v_dep CHAR(3);
  v_arr CHAR(3);
  v_aircraft_id NUMBER;
  v_ac1 NUMBER;
  v_ac2 NUMBER;
  v_econ NUMBER;
  v_biz NUMBER;
  v_first NUMBER;
  v_duration_hours NUMBER;
  v_flight_id NUMBER;
  v_seat_count NUMBER;
BEGIN
  SELECT aircraft_id INTO v_ac1 FROM aircraft WHERE tail_number = 'FD-001';
  SELECT aircraft_id INTO v_ac2 FROM aircraft WHERE tail_number = 'FD-002';

  FOR r IN (
    SELECT r.route_id, dep.airport_code dep_code, arr.airport_code arr_code
    FROM route r
    JOIN airport dep ON dep.airport_id = r.departure_airport_id
    JOIN airport arr ON arr.airport_id = r.arrival_airport_id
    WHERE dep.airport_code IN ('YYZ','YVR','YUL','LAX','JFK')
      AND arr.airport_code IN ('YYZ','YVR','YUL','LAX','JFK')
      AND dep.airport_code <> arr.airport_code
      AND EXISTS (
        SELECT 1 FROM route r2
        WHERE r2.route_id = r.route_id
          AND r2.economy_fare IS NOT NULL
      )
  ) LOOP
    v_route_id := r.route_id;
    v_dep := r.dep_code;
    v_arr := r.arr_code;

    -- simple duration heuristic based on distance
    SELECT CASE
             WHEN distance_km >= 3200 THEN 5.0
             WHEN distance_km >= 2500 THEN 4.5
             WHEN distance_km >= 1500 THEN 3.5
             WHEN distance_km >= 800 THEN 3.0
             ELSE 1.5
           END
    INTO v_duration_hours
    FROM route WHERE route_id = v_route_id;

    SELECT economy_fare, business_fare, first_fare
    INTO v_econ, v_biz, v_first
    FROM route WHERE route_id = v_route_id;

    -- alternate aircraft per route to keep load balanced
    v_aircraft_id := CASE MOD(v_route_id, 2) WHEN 0 THEN v_ac1 ELSE v_ac2 END;

    FOR v_day IN 0 .. 59 LOOP
      FOR v_slot IN 1 .. 2 LOOP
        -- v_slot 1 = morning 08:00, v_slot 2 = afternoon 15:00
        DECLARE
          v_depart_ts TIMESTAMP;
          v_arrive_ts TIMESTAMP;
          v_flight_no VARCHAR2(10);
        BEGIN
          v_depart_ts := CAST(v_start + v_day AS TIMESTAMP) + (CASE v_slot WHEN 1 THEN 8 ELSE 15 END)/24;
          v_arrive_ts := v_depart_ts + (v_duration_hours/24);
          v_flight_no := 'FD' || LPAD(v_route_id, 3, '0') || TO_CHAR(v_day, 'FM00') || CASE v_slot WHEN 1 THEN 'M' ELSE 'A' END;

          BEGIN
            INSERT INTO flight(route_id, flight_number, departure_ts, arrival_ts, aircraft_id, status)
            VALUES (v_route_id, v_flight_no, v_depart_ts, v_arrive_ts, v_aircraft_id, 'SCHEDULED')
            RETURNING flight_id INTO v_flight_id;
          EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
              SELECT flight_id INTO v_flight_id FROM flight WHERE flight_number = v_flight_no;
          END;

          -- seat layout: FIRST 1A/1D/1G/1J, BUSINESS 2A/2D/2G/2J, ECONOMY rows 12-15 ABC/DEF/GHJ
          SELECT COUNT(*) INTO v_seat_count FROM seat_layout WHERE flight_id = v_flight_id;
          IF v_seat_count = 0 THEN
            -- FIRST
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'FIRST', 1, 'A', '1A', 'N', 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'FIRST', 1, 'D', '1D', 'N', 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'FIRST', 1, 'G', '1G', 'N', 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'FIRST', 1, 'J', '1J', 'N', 'N');

            -- BUSINESS
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'BUSINESS', 2, 'A', '2A', 'N', 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'BUSINESS', 2, 'D', '2D', 'N', 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'BUSINESS', 2, 'G', '2G', 'N', 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'BUSINESS', 2, 'J', '2J', 'N', 'N');

            -- ECONOMY rows 12-15
            FOR v_row IN 12 .. 15 LOOP
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'A', TO_CHAR(v_row) || 'A', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'B', TO_CHAR(v_row) || 'B', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'C', TO_CHAR(v_row) || 'C', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'D', TO_CHAR(v_row) || 'D', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'E', TO_CHAR(v_row) || 'E', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'F', TO_CHAR(v_row) || 'F', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
              VALUES (v_flight_id, 'ECONOMY', v_row, 'G', TO_CHAR(v_row) || 'G', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
              INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'ECONOMY', v_row, 'H', TO_CHAR(v_row) || 'H', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
            INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
            VALUES (v_flight_id, 'ECONOMY', v_row, 'J', TO_CHAR(v_row) || 'J', CASE WHEN v_row = 15 THEN 'Y' ELSE 'N' END, 'N');
            END LOOP;
          END IF;

          -- Seed a handful of bookings per flight (avoid seats 12A/12B used later)
          DECLARE
            v_booked NUMBER := 0;
            v_booking_id NUMBER;
            v_customer_id NUMBER;
            v_pnr booking.pnr_code%TYPE;
            v_fare NUMBER;
          BEGIN
            FOR seat_rec IN (
              SELECT seat_no, cabin_class,
                     CASE seat_no
                       WHEN '12C' THEN 1
                       WHEN '12D' THEN 2
                       WHEN '13A' THEN 3
                       WHEN '2A'  THEN 4
                       WHEN '1A'  THEN 5
                       ELSE 99
                     END AS ord
              FROM seat_layout
              WHERE flight_id = v_flight_id
                AND seat_no IN ('12C','12D','13A','2A','1A')
              ORDER BY ord
            ) LOOP
              EXIT WHEN v_booked >= 4; -- cap per flight

              v_booking_id := seq_booking.NEXTVAL;
              v_pnr := 'DB' || LPAD(v_booking_id, 4, '0');

              INSERT INTO customer(customer_id, full_name, contact_info)
              VALUES (seq_customer.NEXTVAL, 'FD Auto ' || v_flight_no || ' ' || seat_rec.seat_no, 'auto.fd@example.com')
              RETURNING customer_id INTO v_customer_id;

              INSERT INTO booking(booking_id, customer_id, flight_id, pnr_code, status, paid_flag)
              VALUES (v_booking_id, v_customer_id, v_flight_id, v_pnr, 'CONFIRMED', 'Y');

              v_fare := CASE seat_rec.cabin_class
                          WHEN 'ECONOMY' THEN v_econ
                          WHEN 'BUSINESS' THEN v_biz
                          ELSE v_first
                        END;

              INSERT INTO ticket(ticket_id, booking_id, flight_id, seat_no, cabin_class, fare_amount, status)
              VALUES (seq_ticket.NEXTVAL, v_booking_id, v_flight_id, seat_rec.seat_no, seat_rec.cabin_class, v_fare, 'ACTIVE');

              v_booked := v_booked + 1;
            END LOOP;
          END;
        END;
      END LOOP;
    END LOOP;
  END LOOP;
END;
/

PROMPT Seeding sample bookings/tickets for first YYZ->YVR and YYZ->YUL flights today...
DECLARE
  v_pnr1 CONSTANT VARCHAR2(6) := 'FD101A';
  v_pnr2 CONSTANT VARCHAR2(6) := 'FD410A';
  v_flt1 NUMBER;
  v_flt2 NUMBER;
  v_b1 NUMBER;
  v_b2 NUMBER;
BEGIN
  -- Clean any prior demo PNRs/customers
  DELETE FROM ticket_audit WHERE ticket_id IN (
    SELECT ticket_id FROM ticket WHERE booking_id IN (SELECT booking_id FROM booking WHERE pnr_code IN (v_pnr1, v_pnr2))
  );
  DELETE FROM ticket WHERE booking_id IN (SELECT booking_id FROM booking WHERE pnr_code IN (v_pnr1, v_pnr2));
  DELETE FROM booking WHERE pnr_code IN (v_pnr1, v_pnr2);
  DELETE FROM customer WHERE full_name IN ('FD Demo Alice','FD Demo Bob');

  -- Earliest YYZ->YVR flight today
  BEGIN
    SELECT flight_id INTO v_flt1 FROM (
      SELECT f.flight_id
      FROM flight f
      JOIN route r ON r.route_id = f.route_id
      JOIN airport d ON d.airport_id = r.departure_airport_id
      JOIN airport a ON a.airport_id = r.arrival_airport_id
      WHERE d.airport_code = 'YYZ'
        AND a.airport_code = 'YVR'
        AND TRUNC(f.departure_ts) = TRUNC(SYSDATE)
      ORDER BY f.departure_ts
    ) WHERE ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN v_flt1 := NULL; END;

  -- Earliest YYZ->YUL flight today
  BEGIN
    SELECT flight_id INTO v_flt2 FROM (
      SELECT f.flight_id
      FROM flight f
      JOIN route r ON r.route_id = f.route_id
      JOIN airport d ON d.airport_id = r.departure_airport_id
      JOIN airport a ON a.airport_id = r.arrival_airport_id
      WHERE d.airport_code = 'YYZ'
        AND a.airport_code = 'YUL'
        AND TRUNC(f.departure_ts) = TRUNC(SYSDATE)
      ORDER BY f.departure_ts
    ) WHERE ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN v_flt2 := NULL; END;

  -- Booking 1: YYZ->YVR seat 12A ECONOMY
  IF v_flt1 IS NOT NULL THEN
    INSERT INTO customer(customer_id, full_name, contact_info)
    VALUES (seq_customer.NEXTVAL, 'FD Demo Alice', 'alice.fd@example.com');

    INSERT INTO booking(booking_id, customer_id, flight_id, pnr_code, status, paid_flag)
    VALUES (seq_booking.NEXTVAL, seq_customer.CURRVAL, v_flt1, v_pnr1, 'CONFIRMED', 'Y')
    RETURNING booking_id INTO v_b1;

    INSERT INTO ticket(ticket_id, booking_id, flight_id, seat_no, cabin_class, fare_amount, status)
    VALUES (
      seq_ticket.NEXTVAL,
      v_b1,
      v_flt1,
      '12A',
      (SELECT cabin_class FROM seat_layout WHERE flight_id = v_flt1 AND seat_no = '12A'),
      (SELECT r.economy_fare FROM route r JOIN flight f ON f.route_id = r.route_id WHERE f.flight_id = v_flt1),
      'ACTIVE'
    );
  END IF;

  -- Booking 2: YYZ->YUL seat 12B ECONOMY
  IF v_flt2 IS NOT NULL THEN
    INSERT INTO customer(customer_id, full_name, contact_info)
    VALUES (seq_customer.NEXTVAL, 'FD Demo Bob', 'bob.fd@example.com');

    INSERT INTO booking(booking_id, customer_id, flight_id, pnr_code, status, paid_flag)
    VALUES (seq_booking.NEXTVAL, seq_customer.CURRVAL, v_flt2, v_pnr2, 'CONFIRMED', 'Y')
    RETURNING booking_id INTO v_b2;

    INSERT INTO ticket(ticket_id, booking_id, flight_id, seat_no, cabin_class, fare_amount, status)
    VALUES (
      seq_ticket.NEXTVAL,
      v_b2,
      v_flt2,
      '12B',
      (SELECT cabin_class FROM seat_layout WHERE flight_id = v_flt2 AND seat_no = '12B'),
      (SELECT r.economy_fare FROM route r JOIN flight f ON f.route_id = r.route_id WHERE f.flight_id = v_flt2),
      'ACTIVE'
    );
  END IF;
END;
/

COMMIT;
PROMPT Front-end demo seed complete (FD* flights for 60 days).
