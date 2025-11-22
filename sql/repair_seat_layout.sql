-- Rebuild seat_layout for all flights (useful if seats are missing/empty)
-- Run this after flights exist. Safe to re-run; it deletes existing seats.

SET DEFINE OFF;

PROMPT Removing existing seat_layout rows...
DELETE FROM seat_layout;
COMMIT;

PROMPT Regenerating seats for all flights (B787-9 layout)
DECLARE
  v_labels CONSTANT VARCHAR2(9) := 'ABCDEFGHJ'; -- skip I
  PROCEDURE add_seat(p_flight NUMBER, p_row NUMBER, p_label CHAR, p_cabin VARCHAR2, p_exit CHAR := 'N', p_extra CHAR := 'N') IS
  BEGIN
    INSERT INTO seat_layout(flight_id, cabin_class, seat_row, seat_col, seat_no, is_exit_row, is_extra_legroom)
    VALUES (p_flight, p_cabin, p_row, p_label, TO_CHAR(p_row) || p_label, p_exit, p_extra);
  END;
BEGIN
  FOR rec IN (SELECT flight_id FROM flight) LOOP
    -- Business rows 7-16 seats A-D-G-J (2-2-2)
    FOR row_num IN 7 .. 16 LOOP
      add_seat(rec.flight_id, row_num, 'A', 'BUSINESS');
      add_seat(rec.flight_id, row_num, 'D', 'BUSINESS');
      add_seat(rec.flight_id, row_num, 'G', 'BUSINESS');
      add_seat(rec.flight_id, row_num, 'J', 'BUSINESS');
    END LOOP;

    -- Economy rows 28-36 seats ABC-DEF-GHJ
    FOR row_num IN 28 .. 36 LOOP
      FOR seat_idx IN 1 .. LENGTH(v_labels) LOOP
        add_seat(rec.flight_id, row_num, SUBSTR(v_labels, seat_idx, 1), 'ECONOMY',
          CASE WHEN row_num IN (28, 36) THEN 'Y' ELSE 'N' END,
          CASE WHEN row_num IN (28, 29) THEN 'Y' ELSE 'N' END);
      END LOOP;
    END LOOP;

    -- First rows 1-4 seats A-D-G-J (1-2-1 style)
    FOR row_num IN 1 .. 4 LOOP
      add_seat(rec.flight_id, row_num, 'A', 'FIRST');
      add_seat(rec.flight_id, row_num, 'D', 'FIRST');
      add_seat(rec.flight_id, row_num, 'G', 'FIRST');
      add_seat(rec.flight_id, row_num, 'J', 'FIRST');
    END LOOP;
  END LOOP;
END;
/

COMMIT;

PROMPT Seat counts by flight:
SELECT flight_id, COUNT(*) AS seats
FROM seat_layout
GROUP BY flight_id
ORDER BY flight_id;
