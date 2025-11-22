# Airline Ticketing Prototype

Full-stack sample for COMP214 term project. Oracle 12c provides the back-end database, while a lightweight Node/Express API and vanilla HTML/JS front end deliver the booking flow (search → seat selection → booking → manage PNR).

## Quick start

```bash
cp .env .env.local # or fill .env directly with Oracle credentials
npm install        # install dependencies
npm run dev        # start API + static UI (http://localhost:3000)
```

Update `.env` with your Oracle server info (host/port/service/SID + credentials). The API needs a reachable Oracle instance containing the schema from `sql/setup.sql`.

## Project layout

| Path | Purpose |
| --- | --- |
| `src/server.js` | Express entry point, loads Oracle pool and API routes |
| `src/routes/` | REST endpoints for flights, seats, bookings |
| `src/services/` | Database access logic (queries / DML) |
| `src/controllers/` | Input validation + response shaping |
| `public/` | Front-end assets (HTML/CSS/JS) |
| `sql/setup.sql` | All DDL/PLSQL/data for schema (tables, sequences, triggers, packages) |
| `sql/tests.sql` | Example script to exercise package/functions |

## API overview

| Method | Endpoint | Description |
| --- | --- | --- |
| `GET /api/flights?from=YYZ&to=YVR&date=2024-05-21` | Search flights |
| `GET /api/seats?flightId=1&cabin=ECONOMY` | Seat map for the flight/cabin |
| `POST /api/bookings` | Create booking (`flightId`, `cabin`, `seatNo`, `passengerName`, `passengerContact`) |
| `GET /api/bookings/:pnr` | Retrieve booking info by PNR |
| `PUT /api/bookings/:pnr/seat` | Change seat (`{ seatNo }`) |
| `DELETE /api/bookings/:pnr` | Cancel booking |

## Database artifacts

- Tables: airport, aircraft, route, flight, seat_layout, customer, booking, ticket, payment, ticket_audit
- Sequences: `seq_customer`, `seq_booking`, `seq_ticket`, `seq_payment`
- Indexes: `idx_flight_route_time`, `idx_ticket_flight`, `idx_booking_customer`
- Triggers: automatic PK assignment + ticket audit trail
- Functions: `fn_available_seats`, `fn_booking_total`
- Procedures: `proc_change_seat`, `proc_cancel_booking`
- Package: `pkg_booking` (wraps create/cancel helpers and uses the functions)

Run `@sql/setup.sql` then `@sql/tests.sql` from SQL*Plus/SQL Developer to populate seed data and verify compiled objects.
