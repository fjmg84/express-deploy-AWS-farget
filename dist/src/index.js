"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const typeorm_1 = require("typeorm");
const User_1 = require("./entity/User");
const app = (0, express_1.default)();
const PORT = process.env.PORT || 3000;
app.use(express_1.default.json());
// Database configuration - ensure we always provide options
const AppDataSource = new typeorm_1.DataSource({
    type: "postgres",
    host: process.env.DB_HOST || "172.21.0.4",
    port: parseInt(process.env.DB_PORT || "5432"),
    username: process.env.DB_USERNAME || "app_user",
    password: process.env.DB_PASSWORD || "dev_password_123",
    database: process.env.DB_NAME || "floci_dev",
    synchronize: true,
    logging: process.env.DB_LOGGING === "true" || true,
    entities: [User_1.User],
});
console.log('Attempting to connect to PostgreSQL...');
console.log(`Host: ${process.env.DB_HOST || "172.21.0.4"}`);
console.log(`Port: ${process.env.DB_PORT || "5432"}`);
console.log(`Database: ${process.env.DB_NAME || "floci_dev"}`);
console.log(`Username: ${process.env.DB_USERNAME || "app_user"}`);
// Set up connection
AppDataSource.initialize()
    .then(() => {
    console.log('Successfully connected to PostgreSQL database');
    // Get the user repository
    const userRepository = AppDataSource.getRepository(User_1.User);
    app.get('/', (req, res) => {
        res.json({ message: 'Hello from Express + Docker!' });
    });
    app.get('/health', async (req, res) => {
        try {
            // Simple query to check DB connection
            await userRepository.query('SELECT 1');
            res.json({ status: 'OK', database: 'connected' });
        }
        catch (dbError) {
            res.status(503).json({ status: 'ERROR', database: 'disconnected', error: dbError.message });
        }
    });
    app.get('/version', (req, res) => {
        res.json({ version: '1.0.0' });
    });
    // New route to get all users
    app.get('/users', async (req, res) => {
        try {
            const users = await userRepository.find();
            res.json(users);
        }
        catch (error) {
            res.status(500).json({ error: 'Failed to fetch users', details: error.message });
        }
    });
    // New route to create a user (for testing)
    app.post('/users', async (req, res) => {
        try {
            const user = userRepository.create(req.body);
            const result = await userRepository.save(user);
            res.status(201).json(result);
        }
        catch (error) {
            res.status(500).json({ error: 'Failed to create user', details: error.message });
        }
    });
    app.listen(PORT, () => {
        console.log(`Server running on port ${PORT}`);
    });
})
    .catch((error) => {
    console.error('Failed to connect to PostgreSQL:', error.message);
    console.error('Please verify:');
    console.error('1. PostgreSQL server is running at 172.21.0.4:5432');
    console.error('2. Database "floci_dev" exists');
    console.error('3. User "app_user" has access with password "dev_password_123"');
    console.error('4. Network allows connection to this address');
    // Start server without DB for testing endpoints
    app.get('/', (req, res) => {
        res.json({ message: 'Hello from Express + Docker! (DB connection failed)' });
    });
    app.get('/health', (req, res) => {
        res.json({ status: 'ERROR', database: 'disconnected', error: error.message });
    });
    app.get('/version', (req, res) => {
        res.json({ version: '1.0.0' });
    });
    app.get('/users', (req, res) => {
        res.status(503).json({ error: 'Database unavailable' });
    });
    app.post('/users', (req, res) => {
        res.status(503).json({ error: 'Database unavailable' });
    });
    app.listen(PORT, () => {
        console.log(`Server running on port ${PORT} (without database)`);
    });
});
//# sourceMappingURL=index.js.map