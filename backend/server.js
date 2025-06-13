const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect('mongodb://localhost:27017/gps_tracker', {
    useNewUrlParser: true,
    useUnifiedTopology: true
});

// Asset Schema
const assetSchema = new mongoose.Schema({
    serialNumber: String,
    name: String,
    model: String,
    deviceName: String,
    imageUrl: String,
    isActive: { type: Boolean, default: false },
    engineOn: { type: Boolean, default: false },
    speed: Number,
    altitude: Number,
    temperature: Number,
    humidity: Number,
    lastKnownLocation: {
        type: { type: String },
        coordinates: [Number]
    },
    lastUpdated: { type: Date, default: Date.now }
});

const Asset = mongoose.model('Asset', assetSchema);

// Routes
// Get all assets
app.get('/api/assets', async (req, res) => {
    try {
        const assets = await Asset.find();
        res.json(assets);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get single asset
app.get('/api/assets/:id', async (req, res) => {
    try {
        const asset = await Asset.findById(req.params.id);
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        res.json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Create asset
app.post('/api/assets', async (req, res) => {
    try {
        const asset = new Asset(req.body);
        await asset.save();
        res.status(201).json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Update asset
app.put('/api/assets/:id', async (req, res) => {
    try {
        const asset = await Asset.findByIdAndUpdate(req.params.id, req.body, { new: true });
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        res.json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Control engine
app.post('/api/assets/:id/engine', async (req, res) => {
    try {
        const asset = await Asset.findByIdAndUpdate(
            req.params.id,
            { engineOn: req.body.state },
            { new: true }
        );
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        res.json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Control power
app.post('/api/assets/:id/power', async (req, res) => {
    try {
        const asset = await Asset.findByIdAndUpdate(
            req.params.id,
            { isActive: req.body.state },
            { new: true }
        );
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        res.json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Trigger alarm
app.post('/api/assets/:id/alarm', async (req, res) => {
    try {
        const asset = await Asset.findById(req.params.id);
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        // Simulate alarm trigger
        res.json({ success: true, message: 'Alarm triggered' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Activate lost mode
app.post('/api/assets/:id/lost-mode', async (req, res) => {
    try {
        const asset = await Asset.findByIdAndUpdate(
            req.params.id,
            { isActive: true, lastUpdated: new Date() },
            { new: true }
        );
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        res.json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Restore defaults
app.post('/api/assets/:id/restore', async (req, res) => {
    try {
        const asset = await Asset.findByIdAndUpdate(
            req.params.id,
            {
                engineOn: false,
                isActive: false,
                speed: 0,
                lastUpdated: new Date()
            },
            { new: true }
        );
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        res.json(asset);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get asset status
app.get('/api/assets/:id/status', async (req, res) => {
    try {
        const asset = await Asset.findById(req.params.id);
        if (!asset) return res.status(404).json({ error: 'Asset not found' });
        
        // Simulate some real-time data
        const status = {
            engineOn: asset.engineOn,
            isActive: asset.isActive,
            speed: Math.random() * 100, // Random speed between 0-100
            altitude: Math.random() * 1000, // Random altitude
            temperature: 20 + Math.random() * 15, // Random temperature 20-35
            humidity: 30 + Math.random() * 40, // Random humidity 30-70
            lastUpdated: new Date(),
            lastKnownLocation: asset.lastKnownLocation
        };

        // Update the asset with new status
        await Asset.findByIdAndUpdate(req.params.id, status);
        res.json(status);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.listen(port, () => {
    console.log(`GPS Tracker API running on http://localhost:${port}`);
});
