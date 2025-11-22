const Joi = require('joi');
const bookingService = require('../services/bookingService');
const { HttpError } = require('../utils/errorHandler');

const createSchema = Joi.object({
  flightId: Joi.number().integer().required(),
  cabin: Joi.string().valid('ECONOMY', 'BUSINESS', 'FIRST').required(),
  seatNo: Joi.string().trim().max(4).required(),
  passengerName: Joi.string().trim().min(2).required(),
  passengerContact: Joi.string().trim().min(4).required()
});

const pnrSchema = Joi.object({
  pnr: Joi.string().alphanum().min(5).max(6).uppercase().required()
});

const seatUpdateSchema = Joi.object({
  seatNo: Joi.string().trim().max(4).required()
});

async function createBooking(req, res, next) {
  try {
    const { value, error } = createSchema.validate(req.body, { abortEarly: false });
    if (error) {
      throw new HttpError(400, 'Invalid booking payload', error.details);
    }
    const data = await bookingService.createBooking(value);
    return res.status(201).json(data);
  } catch (err) {
    return next(err);
  }
}

async function getBooking(req, res, next) {
  try {
    const { value, error } = pnrSchema.validate({ pnr: req.params.pnr });
    if (error) {
      throw new HttpError(400, 'Invalid PNR supplied', error.details);
    }
    const booking = await bookingService.getBookingByPnr(value.pnr);
    return res.json(booking);
  } catch (err) {
    return next(err);
  }
}

async function updateSeat(req, res, next) {
  try {
    const { value: pnrValue, error: pnrError } = pnrSchema.validate({ pnr: req.params.pnr });
    if (pnrError) {
      throw new HttpError(400, 'Invalid PNR supplied', pnrError.details);
    }
    const { value, error } = seatUpdateSchema.validate(req.body);
    if (error) {
      throw new HttpError(400, 'Invalid seat number', error.details);
    }
    const booking = await bookingService.updateSeat(pnrValue.pnr, value.seatNo);
    return res.json(booking);
  } catch (err) {
    return next(err);
  }
}

async function cancelBooking(req, res, next) {
  try {
    const { value, error } = pnrSchema.validate({ pnr: req.params.pnr });
    if (error) {
      throw new HttpError(400, 'Invalid PNR supplied', error.details);
    }
    await bookingService.cancelBooking(value.pnr);
    return res.json({ success: true });
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  createBooking,
  getBooking,
  updateSeat,
  cancelBooking
};
