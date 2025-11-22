const HttpError = require('./httpError');

function errorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  if (err instanceof HttpError) {
    return res.status(err.statusCode).json({
      error: err.message,
      details: err.details || null
    });
  }

  console.error('Unhandled error', err);
  return res.status(500).json({
    error: 'Internal Server Error'
  });
}

module.exports = {
  errorHandler,
  HttpError
};
