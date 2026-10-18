import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || 3000,
  host: process.env.HOST || 'localhost',
  botToken: process.env.BOT_TOKEN || '',
  adminIds: (process.env.ADMIN_IDS || '')
    .split(',')
    .map(id => id.trim())
    .filter(Boolean)
    .map(Number),
  
  defaultRooms: [
    { id: 'room-general', name: '🌍 Global Telegram Lounge', type: 'group', avatar: '💬', members: 124 },
    { id: 'room-durov', name: '⭐ Pavel Durov (Official)', type: 'channel', avatar: '✈️', members: 2480000, isVerified: true },
    { id: 'room-bot', name: '🤖 Secret Message Bot Bridge', type: 'bot', avatar: '🕵️', members: 1 },
    { id: 'room-crypto', name: '💎 VIP Trading Signals', type: 'channel', avatar: '📈', members: 450 }
  ]
};
