const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const http = require("http");
const authRouter = require("./routes/auth");
const documentRouter = require("./routes/document");
const Document = require("./models/document");
const winston = require("winston"); // Importing winston for logging
require('dotenv').config();

const PORT = process.env.PORT || 3001;

const app = express();
var server = http.createServer(app);
var io = require("socket.io")(server);

// Setting up winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'combined.log' })
  ],
});

app.use(cors());
app.use(express.json());
app.use(authRouter);
app.use(documentRouter);

const DB = process.env.MONGODB_URI;

mongoose
  .connect(DB)
  .then(() => {
    logger.info("Connected to MongoDB");
  })
  .catch((err) => {
    logger.error("MongoDB connection error:", err);
  });

io.on("connection", (socket) => {
  logger.info(`New client connected: ${socket.id}`);

  // Listening for incoming socket events
  socket.on("join", (documentId) => {
    socket.join(documentId);
    logger.info(`Socket ${socket.id} joined document: ${documentId}`);
  });

  socket.on("typing", (data) => {
    logger.info(`User is typing in document: ${data.room}`);
    socket.broadcast.to(data.room).emit("changes", data);
    logger.info(`Emitted changes to room: ${data.room} with data:`, data);
  });

  socket.on("save", (data) => {
    logger.info(`Saving data for document: ${data.room}`);
    saveData(data);
  });

  socket.on("disconnect", () => {
    logger.info(`Client disconnected: ${socket.id}`);
  });
});

const saveData = async (data) => {
  try {
    let document = await Document.findById(data.room);
    if (document) {
      document.content = data.delta;
      document = await document.save();
      logger.info(`Document ${data.room} saved successfully.`);
    } else {
      logger.warn(`Document not found: ${data.room}`);
    }
  } catch (error) {
    logger.error("Error saving document:", error);
  }
};

server.listen(PORT, "0.0.0.0", () => {
  logger.info(`Server is running on port ${PORT}`);
});
