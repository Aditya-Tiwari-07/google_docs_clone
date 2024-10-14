const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const http = require("http");
const authRouter = require("./routes/auth");
const documentRouter = require("./routes/document");
const Document = require("./models/document");
require('dotenv').config();

const PORT = process.env.PORT || 3001;

const app = express();
var server = http.createServer(app);
var io = require("socket.io")(server);

app.use(cors());
app.use(express.json());
app.use(authRouter);
app.use(documentRouter);

const DB = process.env.MONGODB_URI;

mongoose
  .connect(DB)
  .then(() => {
    console.log("Connected to MongoDB");
  })
  .catch((err) => {
    console.log("MongoDB connection error:", err);
  });

io.on("connection", (socket) => {
  console.log(`New client connected: ${socket.id}`);

  // Listening for incoming socket events
  socket.on("join", (documentId) => {
    socket.join(documentId);
    console.log(`Socket ${socket.id} joined document: ${documentId}`);
  });

  socket.on("typing", (data) => {
    console.log(`User is typing in document: ${data.room}`);
    socket.broadcast.to(data.room).emit("changes", data);
    console.log(`Emitted changes to room: ${data.room} with data:`, data);
  });

  socket.on("save", (data) => {
    console.log(`Saving data for document: ${data.room}`);
    saveData(data);
  });

  socket.on("disconnect", () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

const saveData = async (data) => {
  try {
    let document = await Document.findById(data.room);
    if (document) {
      document.content = data.delta;
      document = await document.save();
      console.log(`Document ${data.room} saved successfully.`);
    } else {
      console.log(`Document not found: ${data.room}`);
    }
  } catch (error) {
    console.error("Error saving document:", error);
  }
};

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server is running on port ${PORT}`);
});
