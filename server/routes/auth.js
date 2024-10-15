const express = require("express");
const User = require("../models/user");
const jwt = require("jsonwebtoken");
const auth = require("../middlewares/auth");
const authRouter = express.Router();
const winston = require("winston"); // Importing winston for logging

authRouter.post("/api/signup", async (req, res) => {
  try {
    const { name, email, profilePic } = req.body;

    let user = await User.findOne({ email });

    if (!user) {
      user = new User({
        email,
        profilePic,
        name,
      });
      user = await user.save();
      winston.info(`New user created: ${user.email}`);
    } else {
      winston.warn(`User already exists: ${user.email}`);
    }

    const token = jwt.sign({ id: user._id }, "passwordKey");
    winston.info(`Token generated for user: ${user.email}`);

    res.json({ user, token });
  } catch (e) {
    winston.error("Error during signup:", e.message);
    res.status(500).json({ error: e.message });
  }
});

authRouter.get("/", auth, async (req, res) => {
  const user = await User.findById(req.user);
  if (user) {
    winston.info(`User retrieved: ${user.email}`);
    res.json({ user, token: req.token });
  } else {
    winston.warn(`User not found: ${req.user}`);
    res.status(404).json({ error: "User not found" });
  }
});

module.exports = authRouter;
