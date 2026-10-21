'use strict';
const QRCode = require('qrcode');
const path = require('path');

const url = 'http://169.254.55.224:3000/ticket';
const outputPath = path.join(__dirname, 'public', 'qr_ticket.png');

QRCode.toFile(outputPath, url, {
  type: 'png',
  width: 512,
  margin: 3,
  color: {
    dark: '#1E293B',  // Bleu foncé
    light: '#FFFFFF', // Fond blanc
  },
  errorCorrectionLevel: 'H',
}, (err) => {
  if (err) {
    console.error('❌ Erreur:', err);
    process.exit(1);
  }
  console.log('✅ QR Code généré avec succès:', outputPath);
  process.exit(0);
});
