const oracledb = require('oracledb');
const config = require('../config/env');

let pool;

function buildConnectString() {
  // Explicit full connect string if provided
  if (process.env.ORACLE_CONNECT_STRING) {
    return process.env.ORACLE_CONNECT_STRING;
  }

  if (config.oracle.ezConnectService) {
    return config.oracle.ezConnectService;
  }
  if (config.oracle.ezConnectSid) {
    return config.oracle.ezConnectSid;
  }

  const host = config.oracle.host;
  const port = config.oracle.port;
  if (config.oracle.serviceName) {
    return `(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${host})(PORT=${port}))(CONNECT_DATA=(SERVICE_NAME=${config.oracle.serviceName})))`;
  }
  if (config.oracle.sid) {
    return `(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${host})(PORT=${port}))(CONNECT_DATA=(SID=${config.oracle.sid})))`;
  }
  throw new Error('Missing Oracle connection settings. Set ORACLE_EZCONNECT_SERVICE (e.g. //host:1521/service) or ORACLE_HOST/PORT plus ORACLE_SERVICE_NAME.');
}

async function initPool() {
  if (pool) {
    return pool;
  }

  pool = await oracledb.createPool({
    user: config.oracle.user,
    password: config.oracle.password,
    connectString: buildConnectString(),
    poolMin: 1,
    poolMax: 5,
    poolIncrement: 1
  });

  return pool;
}

async function getConnection() {
  if (!pool) {
    await initPool();
  }
  return pool.getConnection();
}

async function closePool() {
  if (pool) {
    await pool.close(5);
    pool = null;
  }
}

module.exports = {
  initPool,
  getConnection,
  closePool
};
