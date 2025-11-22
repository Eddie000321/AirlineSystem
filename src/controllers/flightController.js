const Joi = require('joi');
const flightService = require('../services/flightService');
const { HttpError } = require('../utils/errorHandler');

const searchSchema = Joi.object({
  from: Joi.string().trim().length(3).uppercase().required(),
  to: Joi.string().trim().length(3).uppercase().required(),
  date: Joi.string().regex(/^\d{4}-\d{2}-\d{2}$/).required()
});

async function searchFlights(req, res, next) {
  try {
    const { value, error } = searchSchema.validate(req.query);
    if (error) {
      throw new HttpError(400, 'Invalid search parameters', error.details);
    }
    const flights = await flightService.searchFlights(value);
    return res.json(flights);
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  searchFlights
};
