import express from "express";
import { DataSource, Repository } from "typeorm";
import { User } from "./entity/User";
import { DB_CONFIG } from "./constant";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Basic endpoints that work regardless of DB connection
app.get("/", (req, res) => {
  res.json({ message: "Hello from Express + Docker!" });
});

app.get("/version", (req, res) => {
  res.json({ version: "1.0.0" });
});

// Database configuration - ensure we always provide options
const AppDataSource = new DataSource({
  type: "postgres",
  host: DB_CONFIG.host,
  port: parseInt(DB_CONFIG.port),
  username: DB_CONFIG.username,
  password: DB_CONFIG.password,
  database: DB_CONFIG.database,
  synchronize: true,
  logging: process.env.DB_LOGGING === "true" || true,
  entities: [User],
});

console.log("Attempting to connect to PostgreSQL...");
console.log(`Host: ${DB_CONFIG.host}`);
console.log(`Port: ${DB_CONFIG.port}`);
console.log(`Database: ${DB_CONFIG.database}`);
console.log(`Username: ${DB_CONFIG.username}`);

// Set up connection
let userRepository: Repository<User> | null = null;
let dbConnected = false;

AppDataSource.initialize()
  .then(() => {
    console.log("Successfully connected to PostgreSQL database");
    // Get the user repository
    userRepository = AppDataSource.getRepository(User);
    dbConnected = true;
  })
  .catch((error: any) => {
    console.error("Failed to connect to PostgreSQL:", error.message);
    console.error("Please verify:");
    console.error(
      `1. PostgreSQL server is running at ${DB_CONFIG.host}:${DB_CONFIG.port}`,
    );
    console.error(`2. Database ${DB_CONFIG.database} exists`);
    console.error(
      `3. User ${DB_CONFIG.username} has access with password ${DB_CONFIG.password}`,
    );
    console.error("4. Network allows connection to this address");

    // Continue without DB connection
    userRepository = null;
    dbConnected = false;
  });

// Health endpoint - checks DB connection
app.get("/health", async (req, res) => {
  if (!dbConnected || !userRepository) {
    return res.status(503).json({ status: "ERROR", database: "disconnected" });
  }

  try {
    // Simple query to check DB connection
    await userRepository.query("SELECT 1");
    res.json({ status: "OK", database: "connected" });
  } catch (dbError: any) {
    res
      .status(503)
      .json({
        status: "ERROR",
        database: "disconnected",
        error: dbError.message,
      });
  }
});

// New route to get all users
app.get("/users", async (req, res) => {
  if (!dbConnected || !userRepository) {
    return res.status(503).json({ error: "Database unavailable" });
  }

  try {
    const users = await userRepository.find();
    res.json(users);
  } catch (error: any) {
    res
      .status(500)
      .json({ error: "Failed to fetch users", details: error.message });
  }
});

// New route to create a user (for testing)
app.post("/users", async (req, res) => {
  if (!dbConnected || !userRepository) {
    return res.status(503).json({ error: "Database unavailable" });
  }

  try {
    const user = userRepository.create(req.body);
    const result = await userRepository.save(user);
    res.status(201).json(result);
  } catch (error: any) {
    res
      .status(500)
      .json({ error: "Failed to create user", details: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

console.log("Attempting to connect to PostgreSQL...");
console.log(`Host: ${DB_CONFIG.host}`);
console.log(`Port: ${DB_CONFIG.port}`);
console.log(`Database: ${DB_CONFIG.database}`);
console.log(`Username: ${DB_CONFIG.username}`);
