// spirekey-jwt-relay.js
require('dotenv').config();
const express = require('express');
const ed25519 = require('ed25519');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

// Your relay keypair (generate once, keep private key secret!)
const RELAY_PRIVATE = Buffer.from(process.env.RELAY_PRIVATE_KEY_HEX, 'hex');
const RELAY_PUBLIC  = ed25519.publicKey(RELAY_PRIVATE).toString('base64');

app.get('/public-key', (req, res) => res.send(RELAY_PUBLIC));

app.post('/auth', (req, res) => {
  const { spirekey_pubkey, signature_base64 } = req.body; // signed by device Secure Enclave

  // Message that was signed on device: "spirekey-auth:<timestamp>"
  const message = `spirekey-auth:${Date.now()}`;
  const sigOk = ed25519.verify(message, Buffer.from(signature_base64, 'base64'), Buffer.from(spirekey_pubkey, 'base64'));
  
  if (!sigOk) return res.status(401).send("Invalid signature");

  const token = jwt.sign(
    { sub: spirekey_pubkey, iat: Math.floor(Date.now()/1000) },
    RELAY_PRIVATE.toString('hex'),
    { algorithm: 'EdDSA', expiresIn: '2m' }
  );

  res.json({ jwt: token });
});

app.listen(3001, () => console.log('SpireKey JWT relay running on :3001'));