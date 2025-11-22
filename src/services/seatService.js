const oracledb = require('oracledb');
const { getConnection } = require('../db/pool');

async function getSeats({ flightId, cabin }) {
  const connection = await getConnection();
  try {
    const sql = `
      SELECT
        s.seat_id,
        s.seat_no,
        s.cabin_class,
        s.seat_row,
        s.seat_col,
        s.is_exit_row,
        s.is_wheelchair,
        s.is_extra_legroom,
        NVL(t.status, 'AVAILABLE') AS seat_status
      FROM seat_layout s
      LEFT JOIN (
        SELECT flight_id, seat_no, 'TAKEN' AS status
        FROM ticket
        WHERE status = 'ACTIVE'
      ) t ON t.flight_id = s.flight_id AND t.seat_no = s.seat_no
      WHERE s.flight_id = :flightId
        AND s.cabin_class = :cabin
      ORDER BY s.seat_row, s.seat_col`;

    const result = await connection.execute(
      sql,
      { flightId, cabin },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );
    return result.rows.map((seat) => ({
      seatId: seat.SEAT_ID,
      seatNo: seat.SEAT_NO,
      cabinClass: seat.CABIN_CLASS,
      row: seat.SEAT_ROW,
      column: seat.SEAT_COL,
      status: seat.SEAT_STATUS === 'AVAILABLE' ? 'AVAILABLE' : 'TAKEN',
      isExit: seat.IS_EXIT_ROW === 'Y',
      isWheelchair: seat.IS_WHEELCHAIR === 'Y',
      isExtraLegroom: seat.IS_EXTRA_LEGROOM === 'Y'
    }));
  } finally {
    await connection.close();
  }
}

module.exports = {
  getSeats
};
