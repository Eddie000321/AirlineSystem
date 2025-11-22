const oracledb = require('oracledb');
const { getConnection } = require('../db/pool');

async function searchFlights({ from, to, date }) {
  const connection = await getConnection();
  try {
    const sql = `
      SELECT
        f.flight_id,
        f.flight_number,
        TO_CHAR(f.departure_ts, 'YYYY-MM-DD"T"HH24:MI') AS departure_ts,
        TO_CHAR(f.arrival_ts, 'YYYY-MM-DD"T"HH24:MI')   AS arrival_ts,
        dep.airport_code AS departure_code,
        arr.airport_code AS arrival_code,
        dep.city || ', ' || dep.country AS departure_city,
        arr.city || ', ' || arr.country AS arrival_city,
        f.status,
        r.economy_fare,
        r.business_fare,
        r.first_fare,
        (SELECT COUNT(*) FROM seat_layout s WHERE s.flight_id = f.flight_id AND s.cabin_class = 'ECONOMY')
          - (SELECT COUNT(*) FROM ticket t WHERE t.flight_id = f.flight_id AND t.cabin_class = 'ECONOMY' AND t.status = 'ACTIVE') AS economy_remaining,
        (SELECT COUNT(*) FROM seat_layout s WHERE s.flight_id = f.flight_id AND s.cabin_class = 'BUSINESS')
          - (SELECT COUNT(*) FROM ticket t WHERE t.flight_id = f.flight_id AND t.cabin_class = 'BUSINESS' AND t.status = 'ACTIVE') AS business_remaining,
        (SELECT COUNT(*) FROM seat_layout s WHERE s.flight_id = f.flight_id AND s.cabin_class = 'FIRST')
          - (SELECT COUNT(*) FROM ticket t WHERE t.flight_id = f.flight_id AND t.cabin_class = 'FIRST' AND t.status = 'ACTIVE') AS first_remaining
      FROM flight f
      JOIN route r ON r.route_id = f.route_id
      JOIN airport dep ON dep.airport_id = r.departure_airport_id
      JOIN airport arr ON arr.airport_id = r.arrival_airport_id
      WHERE dep.airport_code = :fromCode
        AND arr.airport_code = :toCode
        AND TRUNC(f.departure_ts) = TRUNC(TO_DATE(:flightDate, 'YYYY-MM-DD'))
      ORDER BY f.departure_ts`;

    const result = await connection.execute(
      sql,
      {
        fromCode: from.toUpperCase(),
        toCode: to.toUpperCase(),
        flightDate: date
      },
      { outFormat: oracledb.OUT_FORMAT_OBJECT }
    );
    return result.rows.map((row) => ({
      flightId: row.FLIGHT_ID,
      flightNumber: row.FLIGHT_NUMBER,
      departureTs: row.DEPARTURE_TS,
      arrivalTs: row.ARRIVAL_TS,
      departureCode: row.DEPARTURE_CODE,
      arrivalCode: row.ARRIVAL_CODE,
      departureCity: row.DEPARTURE_CITY,
      arrivalCity: row.ARRIVAL_CITY,
      status: row.STATUS,
      economyFare: row.ECONOMY_FARE,
      businessFare: row.BUSINESS_FARE,
      firstFare: row.FIRST_FARE,
      economyRemaining: row.ECONOMY_REMAINING,
      businessRemaining: row.BUSINESS_REMAINING,
      firstRemaining: row.FIRST_REMAINING
    }));
  } finally {
    await connection.close();
  }
}

module.exports = {
  searchFlights
};
