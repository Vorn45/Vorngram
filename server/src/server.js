import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { WebSocketServer, WebSocket } from 'ws';
import { Bot } from 'grammy';
import { config } from './config.js';
import { telegramAccount } from './telegramAccount.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PUBLIC_DIR = path.join(__dirname, '../public');

// MIME types dictionary for static server
const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.mp3': 'audio/mpeg',
  '.webm': 'video/webm'
};

// --- 1. HTTP Server for Static Assets ---
const server = http.createServer((req, res) => {
  let reqPath = req.url.split('?')[0];
  if (reqPath === '/' || reqPath === '') {
    reqPath = '/index.html';
  }

  const filePath = path.join(PUBLIC_DIR, reqPath);

  // Security: prevent path traversal
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden');
    return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  });
});

// --- 2. WebSocket Server for Chat & WebRTC Signaling ---
const wss = new WebSocketServer({ server });

// Active Connected Clients: Map<ws, { id, username, avatar, currentRoom }>
const clients = new Map();

// In-Memory Message History per room (persisted for current session)
const messageHistory = new Map();
config.defaultRooms.forEach(room => {
  if (room.id === 'room-durov') {
    messageHistory.set(room.id, [
      {
        id: 'msg-durov-1',
        senderId: 'user_durov',
        senderName: 'Pavel Durov',
        avatar: '✈️',
        text: 'Welcome to my official Telegram channel. Today we continue our mission for global privacy and free speech.',
        timestamp: '10:00 AM',
        isVerified: true
      },
      {
        id: 'msg-durov-2',
        senderId: 'user_durov',
        senderName: 'Pavel Durov',
        avatar: '✈️',
        text: 'Over 950 million active users rely on Telegram every month. Freedom and privacy will always prevail. 🚀',
        timestamp: '11:15 AM',
        isVerified: true
      }
    ]);
  } else if (room.id === 'room-bot') {
    messageHistory.set(room.id, [
      {
        id: 'msg-bot-1',
        senderId: 'bot_secret',
        senderName: '🤖 Secret Message Bot',
        avatar: '🕵️',
        text: 'Live Telegram Bot Bridge is connected to @SecreteMessage123454321ceeetbot. You can chat here, use /secret or /fake on Telegram, or open the 🎭 Fake Message Studio!',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        isSystem: true
      }
    ]);
  } else {
    messageHistory.set(room.id, [
      {
        id: 'sys-1',
        senderId: 'system',
        senderName: 'System Core',
        avatar: '🛡️',
        text: `Welcome to ${room.name}! Real-time messaging, WebRTC Calling, and 🎭 Fake Message Studio are active.`,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        isSystem: true
      }
    ]);
  }
});

function broadcastUserList() {
  const users = Array.from(clients.values()).map(c => ({
    id: c.id,
    username: c.username,
    avatar: c.avatar,
    currentRoom: c.currentRoom
  }));

  const payload = JSON.stringify({
    type: 'user-list',
    users: users
  });

  for (const client of clients.keys()) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  }
}

function sendToUser(targetUserId, payload) {
  const msgStr = JSON.stringify(payload);
  for (const [ws, info] of clients.entries()) {
    if (info.id === targetUserId && ws.readyState === WebSocket.OPEN) {
      ws.send(msgStr);
      return true;
    }
  }
  return false;
}

// Initialize Telegram Account Manager
telegramAccount.init((tgMsg) => {
  const payload = JSON.stringify({
    type: 'tg-live-message',
    message: tgMsg
  });
  for (const client of clients.keys()) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(payload);
    }
  }
});

wss.on('connection', async (ws) => {
  const userId = 'usr_' + Math.random().toString(36).substring(2, 9);
  const defaultAvatars = ['👨‍🚀', '👩‍💻', '🧙‍♂️', '🤖', '🦊', '⚡', '🛡️', '👾'];
  const randomAvatar = defaultAvatars[Math.floor(Math.random() * defaultAvatars.length)];

  clients.set(ws, {
    id: userId,
    username: `User_${userId.slice(-4)}`,
    avatar: randomAvatar,
    currentRoom: 'room-general'
  });

  // Send initial handshake with user identity and default rooms + Telegram account state
  ws.send(JSON.stringify({
    type: 'init-ack',
    user: clients.get(ws),
    rooms: config.defaultRooms,
    history: messageHistory.get('room-general') || [],
    tgAccount: {
      isConnected: telegramAccount.isAuthorized,
      user: telegramAccount.currentUser ? telegramAccount.formatUser(telegramAccount.currentUser) : null
    }
  }));

  // If already connected to Telegram, send dialogs immediately
  if (telegramAccount.isAuthorized) {
    try {
      const dialogs = await telegramAccount.getDialogs();
      ws.send(JSON.stringify({
        type: 'tg-dialogs',
        dialogs: dialogs
      }));
    } catch (e) {
      console.warn('Could not auto-fetch dialogs on connection:', e.message);
    }
  }

  broadcastUserList();

  ws.on('message', async (rawData) => {
    try {
      const data = JSON.parse(rawData);
      const sender = clients.get(ws);
      if (!sender) return;

      switch (data.type) {
        case 'set-profile':
          if (data.username) sender.username = data.username.trim().slice(0, 30);
          if (data.avatar) sender.avatar = data.avatar;
          broadcastUserList();
          break;

        case 'join-room':
          sender.currentRoom = data.roomId;
          ws.send(JSON.stringify({
            type: 'room-history',
            roomId: data.roomId,
            history: messageHistory.get(data.roomId) || []
          }));
          broadcastUserList();
          break;

        case 'send-message': {
          const msgObj = {
            id: 'msg_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
            senderId: sender.id,
            senderName: sender.username,
            avatar: sender.avatar,
            text: data.text,
            media: data.media || null,
            voiceNote: data.voiceNote || null,
            roomId: data.roomId,
            timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
          };

          if (!messageHistory.has(data.roomId)) {
            messageHistory.set(data.roomId, []);
          }
          const hist = messageHistory.get(data.roomId);
          hist.push(msgObj);
          if (hist.length > 100) hist.shift();

          const outPayload = JSON.stringify({
            type: 'new-message',
            message: msgObj
          });

          for (const [clientWs, info] of clients.entries()) {
            if (info.currentRoom === data.roomId && clientWs.readyState === WebSocket.OPEN) {
              clientWs.send(outPayload);
            }
          }

          if (data.roomId === 'room-bot' && bot && config.adminIds.length > 0) {
            config.adminIds.forEach(adminId => {
              bot.api.sendMessage(adminId, `🌐 [Web Chat - ${sender.username}]:\n${data.text}`).catch(() => { });
            });
          }
          break;
        }

        case 'fake-message': {
          const fakeMsgObj = {
            id: 'msg_fake_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
            senderId: data.isOut ? sender.id : ('fake_' + (data.senderName || 'user').toLowerCase().replace(/\s+/g, '_')),
            senderName: data.senderName || 'Anonymous',
            avatar: data.avatar || '🎭',
            text: data.text,
            media: data.media || null,
            voiceNote: data.voiceNote || null,
            roomId: data.roomId || sender.currentRoom,
            timestamp: data.timestamp || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            isOut: !!data.isOut,
            isVerified: !!data.isVerified,
            status: data.status || 'read',
            isFake: true
          };

          if (!messageHistory.has(fakeMsgObj.roomId)) {
            messageHistory.set(fakeMsgObj.roomId, []);
          }
          const hist = messageHistory.get(fakeMsgObj.roomId);
          hist.push(fakeMsgObj);
          if (hist.length > 100) hist.shift();

          const outPayload = JSON.stringify({
            type: 'new-message',
            message: fakeMsgObj
          });

          for (const [clientWs, info] of clients.entries()) {
            if (info.currentRoom === fakeMsgObj.roomId && clientWs.readyState === WebSocket.OPEN) {
              clientWs.send(outPayload);
            }
          }
          break;
        }

        case 'create-custom-room': {
          const newRoom = {
            id: 'custom-' + Date.now(),
            name: data.name || 'New Custom Chat',
            type: data.chatType || 'channel',
            avatar: data.avatar || '💬',
            members: data.members || 1,
            isVerified: !!data.isVerified,
            isCustom: true
          };
          config.defaultRooms.push(newRoom);
          messageHistory.set(newRoom.id, data.initialMessage ? [
            {
              id: 'msg_init_' + Date.now(),
              senderId: 'creator',
              senderName: data.name,
              avatar: data.avatar || '💬',
              text: data.initialMessage,
              timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
              isVerified: !!data.isVerified
            }
          ] : []);

          const roomCreatedPayload = JSON.stringify({
            type: 'room-created',
            room: newRoom
          });

          for (const clientWs of clients.keys()) {
            if (clientWs.readyState === WebSocket.OPEN) {
              clientWs.send(roomCreatedPayload);
            }
          }
          break;
        }

        case 'typing': {
          const typingPayload = JSON.stringify({
            type: 'user-typing',
            userId: sender.id,
            username: sender.username,
            roomId: data.roomId
          });
          for (const [clientWs, info] of clients.entries()) {
            if (info.currentRoom === data.roomId && clientWs !== ws && clientWs.readyState === WebSocket.OPEN) {
              clientWs.send(typingPayload);
            }
          }
          break;
        }

        // --- Telegram MTProto Account Actions ---
        case 'tg-send-code': {
          try {
            const res = await telegramAccount.sendAuthCode(data);
            ws.send(JSON.stringify({ type: 'tg-send-code-res', success: true, ...res }));
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-send-code-res', success: false, error: e.message }));
          }
          break;
        }

        case 'tg-verify-code': {
          try {
            const res = await telegramAccount.verifyAuthCode(data.code);
            ws.send(JSON.stringify({ type: 'tg-verify-code-res', ...res }));
            if (res.success) {
              const dialogs = await telegramAccount.getDialogs();
              ws.send(JSON.stringify({ type: 'tg-dialogs', dialogs }));
            }
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-verify-code-res', success: false, error: e.message }));
          }
          break;
        }

        case 'tg-verify-2fa': {
          try {
            const res = await telegramAccount.verify2FAPassword(data.password);
            ws.send(JSON.stringify({ type: 'tg-verify-2fa-res', ...res }));
            if (res.success) {
              const dialogs = await telegramAccount.getDialogs();
              ws.send(JSON.stringify({ type: 'tg-dialogs', dialogs }));
            }
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-verify-2fa-res', success: false, error: e.message }));
          }
          break;
        }

        case 'tg-get-dialogs': {
          try {
            const dialogs = await telegramAccount.getDialogs(data.limit || 40);
            ws.send(JSON.stringify({ type: 'tg-dialogs', dialogs }));
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-dialogs', dialogs: [], error: e.message }));
          }
          break;
        }

        case 'tg-get-messages': {
          try {
            const messages = await telegramAccount.getMessages(data.chatId, data.limit || 50);
            ws.send(JSON.stringify({ type: 'tg-messages', chatId: data.chatId, messages }));
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-messages', chatId: data.chatId, messages: [], error: e.message }));
          }
          break;
        }

        case 'tg-send-message': {
          try {
            const msg = await telegramAccount.sendMessage(data.chatId, data.text, { voiceNote: data.voiceNote });
            ws.send(JSON.stringify({ type: 'tg-message-sent', success: true, message: msg }));
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-message-sent', success: false, error: e.message }));
          }
          break;
        }

        case 'tg-new-direct-message': {
          try {
            const target = data.target.trim();
            const text = data.text;
            let msg;
            if (data.senderType === 'bot') {
              if (!bot) throw new Error('Telegram bot is not connected');
              const res = await bot.api.sendMessage(target, text);
              msg = {
                id: 'tg_bot_' + res.message_id,
                chatId: target,
                senderName: 'Secret Message Bot',
                text: text,
                timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                isOut: true
              };
            } else {
              msg = await telegramAccount.sendMessage(target, text);
            }
            try {
              const dialogs = await telegramAccount.getDialogs();
              ws.send(JSON.stringify({ type: 'tg-dialogs', dialogs }));
            } catch (_) {}

            ws.send(JSON.stringify({ type: 'tg-direct-msg-sent', success: true, message: msg, target }));
          } catch (e) {
            ws.send(JSON.stringify({ type: 'tg-direct-msg-sent', success: false, error: e.message }));
          }
          break;
        }

        case 'tg-logout': {
          await telegramAccount.logout();
          ws.send(JSON.stringify({ type: 'tg-logout-res', success: true }));
          break;
        }

        // --- WebRTC Signaling Messages ---
        case 'call-user': {
          sendToUser(data.targetUserId, {
            type: 'incoming-call',
            callerId: sender.id,
            callerName: sender.username,
            callerAvatar: sender.avatar,
            callType: data.callType || 'video',
            offer: data.offer
          });
          break;
        }

        case 'call-answer': {
          sendToUser(data.callerId, {
            type: 'call-accepted',
            calleeId: sender.id,
            answer: data.answer
          });
          break;
        }

        case 'call-reject': {
          sendToUser(data.callerId, {
            type: 'call-rejected',
            reason: data.reason || 'declined'
          });
          break;
        }

        case 'ice-candidate': {
          sendToUser(data.targetUserId, {
            type: 'ice-candidate',
            senderId: sender.id,
            candidate: data.candidate
          });
          break;
        }

        case 'end-call': {
          sendToUser(data.targetUserId, {
            type: 'call-ended',
            senderId: sender.id
          });
          break;
        }
      }
    } catch (err) {
      console.error('Error handling WebSocket message:', err);
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
    broadcastUserList();
  });
});

// --- 3. Optional Telegram Bot Bridge (Grammy) ---
let bot = null;
if (config.botToken) {
  try {
    bot = new Bot(config.botToken);

    bot.command('start', async (ctx) => {
      await ctx.reply(
        `👋 *Welcome to Secret Message Bot!* (@${ctx.me?.username || 'bot'})\n\n` +
        `• Send any regular message to mirror it live into the Web Chat.\n` +
        `• Use \`/secret <message>\` to broadcast an anonymous secret message.\n` +
        `• Use \`/fake <Sender Name> | <Text>\` to broadcast a custom fake message.\n` +
        `• Use \`/call\` to receive a 1-click WebRTC Voice & Video call room link!`,
        { parse_mode: 'Markdown' }
      );
    });

    bot.command('secret', async (ctx) => {
      const text = ctx.match || 'Anonymous secret message';
      const msgObj = {
        id: 'sec_' + Date.now(),
        senderId: 'tg_secret',
        senderName: '🕵️ Anonymous Secret Message',
        avatar: '🕵️',
        text: text,
        roomId: 'room-bot',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      if (!messageHistory.has('room-bot')) messageHistory.set('room-bot', []);
      messageHistory.get('room-bot').push(msgObj);

      const outPayload = JSON.stringify({ type: 'new-message', message: msgObj });
      for (const [clientWs, info] of clients.entries()) {
        if (info.currentRoom === 'room-bot' && clientWs.readyState === WebSocket.OPEN) {
          clientWs.send(outPayload);
        }
      }
      await ctx.reply('✅ Secret message delivered to the Web Chat!');
    });

    bot.command('fake', async (ctx) => {
      const input = ctx.match || '';
      const parts = input.split('|');
      const senderName = parts[0]?.trim() || 'Anonymous';
      const text = parts[1]?.trim() || (parts[0]?.trim() || 'Simulated fake message');

      const msgObj = {
        id: 'fake_' + Date.now(),
        senderId: 'tg_fake',
        senderName: `🎭 ${senderName}`,
        avatar: '🎭',
        text: text,
        roomId: 'room-bot',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      if (!messageHistory.has('room-bot')) messageHistory.set('room-bot', []);
      messageHistory.get('room-bot').push(msgObj);

      const outPayload = JSON.stringify({ type: 'new-message', message: msgObj });
      for (const [clientWs, info] of clients.entries()) {
        if (info.currentRoom === 'room-bot' && clientWs.readyState === WebSocket.OPEN) {
          clientWs.send(outPayload);
        }
      }
      await ctx.reply(`✅ Fake message from "${senderName}" delivered to Web Chat!`);
    });

    bot.command('call', async (ctx) => {
      const roomUrl = `http://${config.host}:${config.port}`;
      await ctx.reply(
        `📞 *Incoming Call Portal*\n\nClick below to start instant Voice/Video calling:`,
        {
          parse_mode: 'Markdown',
          reply_markup: {
            inline_keyboard: [
              [{ text: '📹 Join Voice/Video Call', url: roomUrl }]
            ]
          }
        }
      );
    });

    bot.on('message:text', async (ctx) => {
      const fromUser = ctx.from.first_name || 'Telegram User';
      const text = ctx.message.text;

      const msgObj = {
        id: 'tg_' + Date.now(),
        senderId: 'tg_' + ctx.from.id,
        senderName: `📱 ${fromUser} (Telegram)`,
        avatar: '✈️',
        text: text,
        roomId: 'room-bot',
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      if (!messageHistory.has('room-bot')) {
        messageHistory.set('room-bot', []);
      }
      messageHistory.get('room-bot').push(msgObj);

      const outPayload = JSON.stringify({
        type: 'new-message',
        message: msgObj
      });

      for (const [clientWs, info] of clients.entries()) {
        if (info.currentRoom === 'room-bot' && clientWs.readyState === WebSocket.OPEN) {
          clientWs.send(outPayload);
        }
      }
    });

    bot.start({
      onStart: () => console.log('🤖 Telegram Bot Bridge connected successfully!')
    }).catch(err => {
      console.warn('Telegram Bot failed to start (check BOT_TOKEN):', err.message);
    });
  } catch (err) {
    console.warn('Bot setup warning:', err.message);
  }
}

// Start Server
server.listen(config.port, () => {
  console.log(`\n======================================================`);
  console.log(`🚀 TELEGRAM CLONE WITH WEBRTC & REAL TELEGRAM ACCOUNT CONNECT`);
  console.log(`🌐 Server running at: http://localhost:${config.port}`);
  console.log(`======================================================\n`);
});
