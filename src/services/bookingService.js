const oracledb = require('oracledb');
const { getConnection } = require('../db/pool');
const { HttpError } = require('../utils/errorHandler');

function generatePnr() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 6; i += 1) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

async function getFareForCabin(connection, flightId, cabin) {
  const sql = `
    SELECT CASE :cabin
             WHEN 'ECONOMY' THEN r.economy_fare
             WHEN 'BUSINESS' THEN r.business_fare
             WHEN 'FIRST' THEN r.first_fare
           END AS fare
    FROM flight f
    JOIN route r ON r.route_id = f.route_id
    WHERE f.flight_id = :flightId`;

  const result = await connection.execute(
    sql,
    { flightId, cabin },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );

  if (result.rows.length === 0) {
    throw new HttpError(404, 'Flight not found');
  }
  return result.rows[0].FARE;
}

async function assertSeatAvailable(connection, flightId, seatNo) {
  const result = await connection.execute(
    `SELECT COUNT(*) AS cnt
     FROM ticket
     WHERE flight_id = :flightId
       AND seat_no = :seatNo
       AND status = 'ACTIVE'`,
    { flightId, seatNo },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );

  if (result.rows[0].CNT > 0) {
    throw new HttpError(409, 'Seat already taken');
  }
}

async function createBooking({ flightId, cabin, seatNo, passengerName, passengerContact }) {
  const connection = await getConnection();
  try {
    await connection.execute('BEGIN NULL; END;'); // ensure session available
    await assertSeatAvailable(connection, flightId, seatNo);
    const fareAmount = await getFareForCabin(connection, flightId, cabin);
    const pnr = generatePnr();

    const customerResult = await connection.execute(
      `INSERT INTO customer (customer_id, full_name, contact_info, created_at)
       VALUES (seq_customer.NEXTVAL, :name, :contact, SYSTIMESTAMP)
       RETURNING customer_id INTO :customerId`,
      {
        name: passengerName,
        contact: passengerContact,
        customerId: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
      },
      { autoCommit: false }
    );
    const customerId = customerResult.outBinds.customerId[0];

    const bookingResult = await connection.execute(
      `INSERT INTO booking (booking_id, customer_id, flight_id, pnr_code, status, created_at, paid_flag)
       VALUES (seq_booking.NEXTVAL, :customerId, :flightId, :pnr, 'CONFIRMED', SYSTIMESTAMP, 'Y')
       RETURNING booking_id INTO :bookingId`,
      {
        customerId,
        flightId,
        pnr,
        bookingId: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
      },
      { autoCommit: false }
    );
    const bookingId = bookingResult.outBinds.bookingId[0];

    const ticketResult = await connection.execute(
      `INSERT INTO ticket (ticket_id, booking_id, flight_id, seat_no, cabin_class, fare_amount, status, issued_at, ticket_number)
       VALUES (seq_ticket.NEXTVAL, :bookingId, :flightId, :seatNo, :cabin, :fareAmount, 'ACTIVE', SYSTIMESTAMP,
               '300' || TO_CHAR(seq_ticket.CURRVAL))
       RETURNING ticket_number INTO :ticketNumber`,
      {
        bookingId,
        flightId,
        seatNo,
        cabin,
        fareAmount,
        ticketNumber: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 40 }
      },
      { autoCommit: false }
    );

    await connection.commit();

    return {
      pnr,
      ticketNumber: ticketResult.outBinds.ticketNumber[0],
      cabin,
      seatNo,
      amount: fareAmount
    };
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    await connection.close();
  }
}

async function getBookingByPnr(pnr) {
  const connection = await getConnection();
  try {
    const sql = `
      SELECT
        b.booking_id,
        b.pnr_code,
        b.status,
        TO_CHAR(b.created_at, 'YYYY-MM-DD HH24:MI') AS created_at,
        c.full_name,
        c.contact_info,
        f.flight_id,
        f.flight_number,
        TO_CHAR(f.departure_ts, 'YYYY-MM-DD HH24:MI') AS departure,
        TO_CHAR(f.arrival_ts, 'YYYY-MM-DD HH24:MI') AS arrival,
        t.ticket_number,
        t.seat_no,
        t.cabin_class,
        t.fare_amount
      FROM booking b
      JOIN customer c ON c.customer_id = b.customer_id
      JOIN flight f ON f.flight_id = b.flight_id
      JOIN ticket t ON t.booking_id = b.booking_id
      WHERE b.pnr_code = :pnr`;

    const result = await connection.execute(
      sql,
      { pnr },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );

    if (result.rows.length === 0) {
      throw new HttpError(404, 'Reservation not found');
    }

    const row = result.rows[0];
    return {
      bookingId: row.BOOKING_ID,
      pnr: row.PNR_CODE,
      status: row.STATUS,
      createdAt: row.CREATED_AT,
      passenger: {
        name: row.FULL_NAME,
        contact: row.CONTACT_INFO
      },
      flight: {
        id: row.FLIGHT_ID,
        number: row.FLIGHT_NUMBER,
        departure: row.DEPARTURE,
        arrival: row.ARRIVAL
      },
      ticket: {
        ticketNumber: row.TICKET_NUMBER,
        seatNo: row.SEAT_NO,
        cabin: row.CABIN_CLASS,
        fare: row.FARE_AMOUNT
      }
    };
  } finally {
    await connection.close();
  }
}

async function updateSeat(pnr, seatNo) {
  const connection = await getConnection();
  try {
    const booking = await getBookingByPnr(pnr);
    await assertSeatAvailable(connection, booking.flight.id, seatNo);

    const result = await connection.execute(
      `UPDATE ticket
       SET seat_no = :seatNo
       WHERE booking_id = :bookingId
       RETURNING seat_no INTO :newSeat`,
      {
        seatNo,
        bookingId: booking.bookingId,
        newSeat: { dir: oracledb.BIND_OUT, type: oracledb.STRING, maxSize: 5 }
      },
      { autoCommit: false }
    );
    await connection.commit();
    return {
      ...booking,
      ticket: { ...booking.ticket, seatNo: result.outBinds.newSeat[0] }
    };
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    await connection.close();
  }
}

async function cancelBooking(pnr) {
  const connection = await getConnection();
  try {
    const result = await connection.execute(
      `UPDATE booking
       SET status = 'CANCELLED'
       WHERE pnr_code = :pnr
       RETURNING booking_id INTO :bookingId`,
      {
        pnr,
        bookingId: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
      },
      { autoCommit: false }
    );

    if (result.rowsAffected === 0) {
      throw new HttpError(404, 'Reservation not found');
    }

    const bookingId = result.outBinds.bookingId[0];
    await connection.execute(
      `UPDATE ticket
       SET status = 'VOID'
       WHERE booking_id = :bookingId`,
      { bookingId },
      { autoCommit: false }
    );
    await connection.commit();
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    await connection.close();
  }
}

module.exports = {
  createBooking,
  getBookingByPnr,
  updateSeat,
  cancelBooking
};
