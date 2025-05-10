const express = require('express');
const router = express.Router();
const User = require('../models/Users');
const jwt = require('jsonwebtoken');
const { isErrored } = require('stream');

// const JWT_SECRET = 'Z4fR!@c8vX3m$Lp9sWq#J2eYb%N7Tk0R'; 

// Tạo đăng ký người dùng ----------------- POST  : /api/auth/register
router.post('/register', async (req, res) =>  {
    try {
        const { username, password, email, phoneNumber } = req.body;
        if (!username || !password || !email || !phoneNumber) {
            return res.status(400).json({ message: 'All fields are required' });
        }
        const existingUser = await User.findOne ({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'Email already exists' });
        }
        const user = new User({
            username,
            password,
            email,
            phoneNumber,
        });
        await user.save();
        const token = jwt.sign({ id: user._id }, JWT_SECRET, { expiresIn: '1h' });
        res.status(201).json({ token, user: { id: user._id, username: user.username, email: user.email, phoneNumber: user.phoneNumber } });
    } catch (error) {
      //  console.error('Error registering user:', error);
        res.status(500).json({ message: 'Internal server error' });
    }
});

// Đăng nhập người dùng ----------------- POST  : /api/auth/login
router.post('/login', async (req, res) => {
    try {
        const {email, password } = req.body;
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }
        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }   
        const token = jwt.sign({ id: user._id }, JWT_SECRET, { expiresIn: '1h' });

        res.status(200).json({ token, user: { 
             id: user._id,
             username: user.username, 
             email: user.email,
             phoneNumber: user.phoneNumber } });

    }catch (error) {
        console.error('Error logging in user:', error);
        res.status(500).json({ message: 'Internal server error' });
    }
});

// đăng xuất người dùng ----------------- POST  : /api/auth/logout
router.post('/logout', (req, res) => {
    // Xóa token hoặc thực hiện các hành động khác để đăng xuất
    res.status(200).json({ message: 'Logged out successfully' });
});
module.exports = router;