const Joi = require('joi');
const seatService = require('../services/seatService');
const { HttpError } = require('../utils/errorHandler');

const seatSchema = Joi.object({
  flightId: Joi.number().integer().required(),
  cabin: Joi.string().valid('ECONOMY', 'BUSINESS', 'FIRST').required()
});

async function getSeats(req, res, next) {
  try {
    const { value, error } = seatSchema.validate({
      flightId: Number(req.query.flightId || req.params.flightId),
      cabin: req.query.cabin || req.params.cabin
    });
    if (error) {
      throw new HttpError(400, 'Invalid seat request', error.details);
    }
    const seats = await seatService.getSeats(value);
    return res.json(seats);
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  getSeats
};
