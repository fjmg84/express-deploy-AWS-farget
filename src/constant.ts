const DB_HOST = process.env.DB_HOST || "localhost";
const DB_PORT = process.env.DB_PORT || "7001";
const DB_NAME = process.env.DB_NAME || "floci_dev";
const DB_USERNAME = process.env.DB_USERNAME || "app_user";
const DB_PASSWORD = process.env.DB_PASSWORD || "dev_password_123";
const DB_LOGGING = process.env.DB_LOGGING === "true" || true;


export const DB_CONFIG = {
  host: DB_HOST,
  port: DB_PORT,
  username: DB_USERNAME,
  password: DB_PASSWORD,
  database: DB_NAME,
  logging: DB_LOGGING,
};