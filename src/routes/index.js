const express = require('express');
const flightController = require('../controllers/flightController');
const seatController = require('../controllers/seatController');
const bookingController = require('../controllers/bookingController');

const router = express.Router();

router.get('/health', (req, res) => res.json({ status: 'ok' }));
router.get('/flights', flightController.searchFlights);
router.get('/seats', seatController.getSeats);
router.post('/bookings', bookingController.createBooking);
router.get('/bookings/:pnr', bookingController.getBooking);
router.put('/bookings/:pnr/seat', bookingController.updateSeat);
router.delete('/bookings/:pnr', bookingController.cancelBooking);

module.exports = router;
