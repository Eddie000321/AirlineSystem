# Airline Ticketing Prototype

Full-stack sample for COMP214 term project. Oracle 12c provides the back-end database, while a lightweight Node/Express API and vanilla HTML/JS front end deliver the booking flow (search → seat selection → booking → manage PNR).

## Quick start

```bash
cp .env.sample .env   # fill in Oracle host/user/password/SID or service
npm install           # install dependencies
npm run dev           # start API + static UI (http://localhost:3000)
```

Update `.env` with your Oracle server info (host/port/service/SID + credentials). The API needs a reachable Oracle instance containing the schema from `sql/setup.sql`. If you are sharing the project, commit only `.env.sample`; teammates can copy it to `.env` and fill their own credentials.

## Project layout

| Path | Purpose |
| --- | --- |
| `src/server.js` | Express entry point, loads Oracle pool and API routes |
| `src/routes/` | REST endpoints for flights, seats, bookings |
| `src/services/` | Database access logic (queries / DML) |
| `src/controllers/` | Input validation + response shaping |
| `public/` | Front-end assets (HTML/CSS/JS) |
| `sql/assignment_ready.sql` | All DDL/PLSQL for schema (tables, sequences, triggers, packages) |
| `sql/tests.sql` | Minimal, repeatable demo script (creates its own flight/seats/bookings) |
| `sql/seed_manual.sql` | Deterministic manual seed (no randomness/loops) for sample data |
| `sql/seed_front_demo.sql` | Front-end aligned seed: YYZ↔YVR/YUL/LAX/JFK routes + 60 days of FD* flights with matching seat layouts |

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

- Tables: airport, aircraft, route, flight, seat_layout, customer, booking, ticket, ticket_audit
- Sequences: `seq_customer`, `seq_booking`, `seq_ticket`
- Indexes: `idx_flight_route_time`, `idx_ticket_flight`, `idx_booking_customer`
- Triggers: automatic PK assignment + ticket audit trail
- Functions: `fn_available_seats`, `fn_booking_total`
- Procedures: `proc_change_seat` (ticket-level seat change), `proc_cancel_booking`
- Package: `pkg_booking` (wraps create/cancel helpers and uses the functions)

Run `@sql/assignment_ready.sql` then `@sql/tests.sql` from SQL*Plus/SQL Developer to create the schema and exercise the helpers. Seed data is intentionally omitted; the tests script creates a minimal flight + seats for demonstration. For the UI demo, run `@sql/seed_front_demo.sql` to preload YYZ↔YVR/YUL/LAX/JFK flights (60 days) with seat layouts that match the front-end map.
