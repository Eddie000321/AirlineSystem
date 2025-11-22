const oracledb = require('oracledb');
const config = require('../config/env');

let pool;

function buildConnectString() {
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
  throw new Error('Missing Oracle service name or SID in environment variables.');
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
