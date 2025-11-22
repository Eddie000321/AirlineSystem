const path = require('path');
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const config = require('./config/env');
const routes = require('./routes');
const { initPool, closePool } = require('./db/pool');
const { errorHandler } = require('./utils/errorHandler');

const app = express();

app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

app.use('/api', routes);
app.use('/', express.static(path.join(__dirname, '..', 'public')));

app.use(errorHandler);

async function start() {
  try {
    await initPool();
    app.listen(config.appPort, () => {
      console.log(`Airline API listening on port ${config.appPort}`);
    });
  } catch (err) {
    console.error('Failed to start server', err);
    process.exit(1);
  }
}

start();

let shuttingDown = false;
async function gracefulShutdown(signal) {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  console.log(`Received ${signal}, closing Oracle pool...`);
  try {
    await closePool();
  } catch (err) {
    // Ignore pool closing races (e.g., double SIGINT)
    if (err && err.message && err.message.includes('pool is closing')) {
      console.warn('Pool already closing, continuing shutdown');
    } else {
      console.error('Error during pool close', err);
    }
  } finally {
    process.exit(0);
  }
}

process.on('SIGINT', gracefulShutdown);
process.on('SIGTERM', gracefulShutdown);
