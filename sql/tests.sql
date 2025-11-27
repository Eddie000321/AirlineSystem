-- Canadian reference smoke tests without relying on pre-seeded data.
-- Builds real Canadian airports/routes/flights (YYZ↔YVR, YYZ↔YUL),
-- seeds seats, books/cancels a ticket, exercises helpers, and shows audit.
SET SERVEROUTPUT ON;

PROMPT Resetting demo flight data (AC101/AC105/AC410)...
BEGIN
  DELETE FROM ticket_audit WHERE ticket_id IN (
    SELECT t.ticket_id
    FROM ticket t
    JOIN flight f ON f.flight_id = t.flight_id
    WHERE f.flight_number IN ('AC101','AC105','AC410')
  );

  DELETE FROM ticket
  WHERE flight_id IN (SELECT flight_id FROM flight WHERE flight_number IN ('AC101','AC105','AC410'));

  DELETE FROM booking
  WHERE flight_id IN (SELECT flight_id FROM flight WHERE flight_number IN ('AC101','AC105','AC410'));

  DELETE FROM seat_layout
  WHERE flight_id IN (SELECT flight_id FROM flight WHERE flight_number IN ('AC101','AC105','AC410'));

  DELETE FROM flight WHERE flight_number IN ('AC101','AC105','AC410');
END;
/

PROMPT Creating Canadian airports, aircraft, routes, flights, and seats...
DECLARE
  v_yyz NUMBER;
  v_yvr NUMBER;
  v_yul NUMBER;
  v_route_yyz_yvr NUMBER;
  v_route_yyz_yul NUMBER;
  v_ac1 NUMBER;
  v_ac2 NUMBER;
  v_flt_ac101 NUMBER;
  v_flt_ac105 NUMBER;
  v_flt_ac410 NUMBER;
  v_exists NUMBER;
BEGIN
  -- Airports
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('YYZ', 'Toronto Pearson', 'Toronto', 'Canada'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('YVR', 'Vancouver Intl', 'Vancouver', 'Canada'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;
  BEGIN INSERT INTO airport(airport_code, name, city, country) VALUES ('YUL', 'Montreal Trudeau', 'Montreal', 'Canada'); EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL; END;

  SELECT airport_id INTO v_yyz FROM airport WHERE airport_code = 'YYZ';
  SELECT airport_id INTO v_yvr FROM airport WHERE airport_code = 'YVR';
  SELECT airport_id INTO v_yul FROM airport WHERE airport_code = 'YUL';

  -- Aircraft
  BEGIN
    INSERT INTO aircraft(model, tail_number, total_seats) VALUES ('Boeing 737-8', 'C-AC01', 174)
    RETURNING aircraft_id INTO v_ac1;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT aircraft_id INTO v_ac1 FROM aircraft WHERE tail_number = 'C-AC01';
  END;
  BEGIN
    INSERT INTO aircraft(model, tail_number, total_seats) VALUES ('Airbus A220-300', 'C-AC22', 137)
    RETURNING aircraft_id INTO v_ac2;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT aircraft_id INTO v_ac2 FROM aircraft WHERE tail_number = 'C-AC22';
  END;

  -- Routes
  BEGIN
    INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
    VALUES (v_yyz, v_yvr, 3358, 320, 980, 1600)
    RETURNING route_id INTO v_route_yyz_yvr;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      SELECT route_id INTO v_route_yyz_yvr FROM route WHERE departure_airport_id = v_yyz AND arrival_airport_id = v_yvr;
  END;

  BEGIN
    INSERT INTO route(departure_airport_id, arrival_airport_id, distance_km, economy_fare, business_fare, first_fare)
    VALUES (v_yyz, v_yul, 500, 180, 620, 950)
    RETURNING route_id INTO v_route_yyz_yul;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      SELECT route_id INTO v_route_yyz_yul FROM route WHERE departure_airport_id = v_yyz AND arrival_airport_id = v_yul;
  END;

  -- Flights
  BEGIN
    INSERT INTO flight(route_id, flight_number, departure_ts, arrival_ts, aircraft_id, status)
    VALUES (v_route_yyz_yvr, 'AC101', TRUNC(SYSTIMESTAMP) + (9/24), TRUNC(SYSTIMESTAMP) + (11.25/24), v_ac1, 'SCHEDULED')
    RETURNING flight_id INTO v_flt_ac101;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT flight_id INTO v_flt_ac101 FROM flight WHERE flight_number = 'AC101';
  END;

  BEGIN
    INSERT INTO flight(route_id, flight_number, departure_ts, arrival_ts, aircraft_id, status)
    VALUES (v_route_yyz_yvr, 'AC105', TRUNC(SYSTIMESTAMP) + (15/24), TRUNC(SYSTIMESTAMP) + (17.25/24), v_ac1, 'SCHEDULED')
    RETURNING flight_id INTO v_flt_ac105;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT flight_id INTO v_flt_ac105 FROM flight WHERE flight_number = 'AC105';
  END;

  BEGIN
    INSERT INTO flight(route_id, flight_number, departure_ts, arrival_ts, aircraft_id, status)
    VALUES (v_route_yyz_yul, 'AC410', TRUNC(SYSTIMESTAMP) + (7.5/24), TRUNC(SYSTIMESTAMP) + (8.75/24), v_ac2, 'SCHEDULED')
    RETURNING flight_id INTO v_flt_ac410;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN SELECT flight_id INTO v_flt_ac410 FROM flight WHERE flight_number = 'AC410';
  END;

  -- Seats (small deterministic layouts)
  FOR rec IN (SELECT flight_id, flight_number FROM flight WHERE flight_number IN ('AC101','AC105')) LOOP
    SELECT COUNT(*) INTO v_exists FROM seat_layout WHERE flight_id = rec.flight_id;
    IF v_exists = 0 THEN
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'FIRST', 1, 'A', '1A', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'FIRST', 1, 'C', '1C', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'BUSINESS', 2, 'A', '2A', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'BUSINESS', 2, 'C', '2C', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'ECONOMY', 12, 'A', '12A', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'ECONOMY', 12, 'B', '12B', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'ECONOMY', 12, 'C', '12C', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'ECONOMY', 13, 'A', '13A', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'ECONOMY', 13, 'B', '13B', 'N', 'N');
      INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
      VALUES (rec.flight_id, 'ECONOMY', 13, 'C', '13C', 'N', 'N');
    END IF;
  END LOOP;

  SELECT COUNT(*) INTO v_exists FROM seat_layout WHERE flight_id = v_flt_ac410;
  IF v_exists = 0 THEN
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'FIRST', 1, 'A', '1A', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'BUSINESS', 3, 'A', '3A', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'BUSINESS', 3, 'C', '3C', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'ECONOMY', 15, 'A', '15A', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'ECONOMY', 15, 'B', '15B', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'ECONOMY', 15, 'C', '15C', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'ECONOMY', 16, 'A', '16A', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'ECONOMY', 16, 'B', '16B', 'N', 'N');
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (v_flt_ac410, 'ECONOMY', 16, 'C', '16C', 'N', 'N');
  END IF;
END;
/

PROMPT Package demo - create booking, totals, seat change, cancel (AC101)
DECLARE
  v_pnr   booking.pnr_code%TYPE;
  v_ticket pkg_booking.t_ticket_summary;
  v_booking_id booking.booking_id%TYPE;
  v_ticket_id ticket.ticket_id%TYPE;
  v_flight_id flight.flight_id%TYPE;
  v_seat_after ticket.seat_no%TYPE;
  v_booking_status booking.status%TYPE;
BEGIN
  SELECT flight_id INTO v_flight_id FROM flight WHERE flight_number = 'AC101';

  pkg_booking.pr_create_booking(
    p_customer_name => 'Package Tester',
    p_contact       => 'package@tester.com',
    p_flight_id     => v_flight_id,
    p_seat_no       => '12A',
    o_pnr           => v_pnr,
    o_ticket        => v_ticket
  );

  SELECT booking_id INTO v_booking_id FROM booking WHERE pnr_code = v_pnr;
  SELECT ticket_id INTO v_ticket_id FROM ticket WHERE booking_id = v_booking_id;

  DBMS_OUTPUT.PUT_LINE('PNR = ' || v_pnr || ', Ticket = ' || v_ticket.ticket_number || ', Seat = ' || v_ticket.seat_no);
  DBMS_OUTPUT.PUT_LINE('Econ seats left after booking = ' || fn_available_seats(v_flight_id, 'ECONOMY'));
  DBMS_OUTPUT.PUT_LINE('Booking total = ' || fn_booking_total(v_booking_id));

  proc_change_seat(v_ticket_id, '12B');
  SELECT seat_no INTO v_seat_after FROM ticket WHERE ticket_id = v_ticket_id;
  DBMS_OUTPUT.PUT_LINE('Seat after change = ' || v_seat_after);

  pkg_booking.pr_cancel_booking(v_pnr);
  SELECT status INTO v_booking_status FROM booking WHERE booking_id = v_booking_id;
  DBMS_OUTPUT.PUT_LINE('Booking status after cancel = ' || v_booking_status);

  UPDATE ticket
  SET ticket_number = 'TK' || TO_CHAR(seq_ticket.NEXTVAL)
  WHERE ticket_id = v_ticket_id;
END;
/

PROMPT Ticket audit trail (latest 5)
SELECT audit_id, ticket_id, action, seat_no, action_ts
FROM ticket_audit
ORDER BY audit_id DESC
FETCH FIRST 5 ROWS ONLY;
