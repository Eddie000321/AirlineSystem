const dotenv = require('dotenv');

dotenv.config();

const config = {
  appPort: process.env.APP_PORT || 3000,
  oracle: {
    host: process.env.ORACLE_HOST || 'localhost',
    port: process.env.ORACLE_PORT || 1521,
    serviceName: process.env.ORACLE_SERVICE_NAME || '',
    sid: process.env.ORACLE_SID || '',
    user: process.env.ORACLE_USER || '',
    password: process.env.ORACLE_PASSWORD || '',
    ezConnectService: process.env.ORACLE_EZCONNECT_SERVICE || '',
    ezConnectSid: process.env.ORACLE_EZCONNECT_SID || ''
  }
};

module.exports = config;
