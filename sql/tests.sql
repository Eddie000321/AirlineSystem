-- Basic smoke tests for the airline schema.
SET SERVEROUTPUT ON;

PROMPT Available flights YYZ → YVR on 2024-05-21
SELECT f.flight_id,
       f.flight_number,
       TO_CHAR(f.departure_ts, 'HH24:MI') AS depart_time,
       TO_CHAR(f.arrival_ts, 'HH24:MI') AS arrive_time,
       fn_available_seats(f.flight_id, 'ECONOMY') AS econ_left
FROM flight f
JOIN route r ON r.route_id = f.route_id
JOIN airport dep ON dep.airport_id = r.departure_airport_id
JOIN airport arr ON arr.airport_id = r.arrival_airport_id
WHERE dep.airport_code = 'YYZ'
  AND arr.airport_code = 'YVR'
  AND TRUNC(f.departure_ts) = DATE '2024-05-21';

PROMPT Package demo - create booking
DECLARE
  v_pnr   booking.pnr_code%TYPE;
  v_ticket pkg_booking.t_ticket_summary;
BEGIN
  pkg_booking.pr_create_booking(
    p_customer_name => 'Package Tester',
    p_contact       => 'package@tester.com',
    p_flight_id     => 1,
    p_cabin         => 'ECONOMY',
    p_seat_no       => '28C',
    o_pnr           => v_pnr,
    o_ticket        => v_ticket
  );
  DBMS_OUTPUT.PUT_LINE('PNR = ' || v_pnr || ', Ticket = ' || v_ticket.ticket_number);
END;
/

PROMPT Seat availability after booking
SELECT fn_available_seats(1, 'ECONOMY') AS econ_left FROM dual;

PROMPT Cancel booking
BEGIN
  pkg_booking.pr_cancel_booking('&PNR');
END;
/
