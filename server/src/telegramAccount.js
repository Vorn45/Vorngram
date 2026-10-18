import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { TelegramClient, Api } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { NewMessage } from 'telegram/events/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SESSION_FILE = path.join(__dirname, '../session.json');

const DEFAULT_API_ID = parseInt(process.env.API_ID || '2040');
const DEFAULT_API_HASH = process.env.API_HASH || 'b18441a1ff607e10a989891a5462e627';

class TelegramAccountManager {
  constructor() {
    this.client = null;
    this.session = null;
    this.isAuthorized = false;
    this.currentUser = null;
    this.pendingAuth = null;
    this.onNewMessageCallback = null;
    this.avatarCache = new Map();
  }

  loadSessionData() {
    try {
      if (fs.existsSync(SESSION_FILE)) {
        const raw = fs.readFileSync(SESSION_FILE, 'utf-8');
        return JSON.parse(raw);
      }
    } catch (e) {
      console.warn('Could not read session file:', e.message);
    }
    return null;
  }

  saveSessionData(data) {
    try {
      fs.writeFileSync(SESSION_FILE, JSON.stringify(data, null, 2), 'utf-8');
    } catch (e) {
      console.error('Could not save session file:', e.message);
    }
  }

  clearSessionData() {
    try {
      if (fs.existsSync(SESSION_FILE)) {
        fs.unlinkSync(SESSION_FILE);
      }
    } catch (e) {
      console.warn('Could not delete session file:', e.message);
    }
    this.isAuthorized = false;
    this.currentUser = null;
    this.pendingAuth = null;
  }

  async init(onNewMessageCallback) {
    this.onNewMessageCallback = onNewMessageCallback;
    const saved = this.loadSessionData();

    if (saved && saved.sessionString && saved.apiId && saved.apiHash) {
      console.log('🔄 Restoring saved Telegram MTProto account session...');
      try {
        this.session = new StringSession(saved.sessionString);
        this.client = new TelegramClient(this.session, saved.apiId, saved.apiHash, {
          connectionRetries: 5,
        });

        await this.client.connect();
        const authorized = await this.client.isUserAuthorized();
        if (authorized) {
          this.isAuthorized = true;
          this.currentUser = await this.client.getMe();
          console.log(`✅ Telegram Account connected as: @${this.currentUser.username || this.currentUser.firstName} (${this.currentUser.phone})`);
          this.setupEventListeners();
          return { isConnected: true, user: this.formatUser(this.currentUser) };
        } else {
          console.log('Saved session is no longer authorized.');
          this.clearSessionData();
        }
      } catch (err) {
        console.warn('Error restoring Telegram session:', err.message);
      }
    }
    return { isConnected: false, user: null };
  }

  setupEventListeners() {
    if (!this.client) return;

    this.client.addEventHandler(async (event) => {
      try {
        const message = event.message;
        if (!message) return;

        const sender = await message.getSender();
        const chat = await message.getChat();

        let mediaDataUrl = null;
        let voiceDataUrl = null;
        let isVoice = false;

        const doc = message.media?.document || message.document;
        const docMime = doc?.mimeType || '';

        if (message.media) {
          if (message.photo || (docMime && docMime.startsWith('image/'))) {
            try {
              const buffer = await this.client.downloadMedia(message, { workers: 1 });
              if (buffer && buffer.length > 0) {
                const mime = message.photo ? 'image/jpeg' : (docMime || 'image/jpeg');
                mediaDataUrl = `data:${mime};base64,${buffer.toString('base64')}`;
              }
            } catch (e) {}
          } else if (docMime && (docMime.startsWith('audio/') || docMime.includes('ogg'))) {
            isVoice = true;
            try {
              const buffer = await this.client.downloadMedia(message, { workers: 1 });
              if (buffer && buffer.length > 0) {
                voiceDataUrl = `data:${docMime};base64,${buffer.toString('base64')}`;
              }
            } catch (e) {}
            if (!voiceDataUrl) voiceDataUrl = 'voice_note.ogg';
          }
        }

        const cId = chat ? chat.id.toString() : (sender ? sender.id.toString() : 'unknown');
        const sId = sender ? sender.id.toString() : 'unknown';
        const senderAvatar = this.avatarCache.get(sId) || this.avatarCache.get(cId) || null;

        const formattedMsg = {
          id: 'tg_msg_' + message.id,
          rawId: message.id,
          chatId: cId,
          chatTitle: chat ? (chat.title || chat.username || `${chat.firstName || ''} ${chat.lastName || ''}`.trim()) : 'Chat',
          senderId: sId,
          senderName: sender ? (`${sender.firstName || ''} ${sender.lastName || ''}`.trim() || sender.username || 'Telegram User') : 'User',
          avatar: senderAvatar,
          text: message.message || '',
          media: mediaDataUrl,
          voiceNote: isVoice ? (voiceDataUrl || 'voice_note.ogg') : null,
          timestamp: new Date(message.date * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          isOut: message.out || false
        };

        if (this.onNewMessageCallback) {
          this.onNewMessageCallback(formattedMsg);
        }
      } catch (e) {
        console.error('Error in Telegram event listener:', e);
      }
    }, new NewMessage({}));
  }

  formatUser(user) {
    if (!user) return null;
    return {
      id: user.id.toString(),
      firstName: user.firstName || '',
      lastName: user.lastName || '',
      username: user.username || '',
      phone: user.phone || '',
      displayName: `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.username || 'Telegram User'
    };
  }

  async sendAuthCode({ phone, apiId, apiHash }) {
    const finalApiId = parseInt(apiId) || DEFAULT_API_ID;
    const finalApiHash = (apiHash && apiHash.trim()) || DEFAULT_API_HASH;
    const cleanPhone = phone.replace(/[\s\-\(\)]/g, '');

    if (!cleanPhone) {
      throw new Error('Please enter a valid phone number with country code (e.g. +855...)');
    }

    this.session = new StringSession('');
    this.client = new TelegramClient(this.session, finalApiId, finalApiHash, {
      connectionRetries: 5,
    });

    await this.client.connect();

    const sendCodeResult = await this.client.sendCode(
      {
        apiId: finalApiId,
        apiHash: finalApiHash,
      },
      cleanPhone
    );

    this.pendingAuth = {
      phone: cleanPhone,
      phoneCodeHash: sendCodeResult.phoneCodeHash,
      apiId: finalApiId,
      apiHash: finalApiHash,
      isCodeViaApp: sendCodeResult.isCodeViaApp
    };

    return {
      success: true,
      phone: cleanPhone,
      phoneCodeHash: sendCodeResult.phoneCodeHash,
      isCodeViaApp: sendCodeResult.isCodeViaApp
    };
  }

  async verifyAuthCode(phoneCode) {
    if (!this.pendingAuth || !this.client) {
      throw new Error('No pending login request. Please request a code first.');
    }

    try {
      await this.client.invoke(
        new Api.auth.SignIn({
          phoneNumber: this.pendingAuth.phone,
          phoneCodeHash: this.pendingAuth.phoneCodeHash,
          phoneCode: phoneCode.trim()
        })
      );

      this.isAuthorized = true;
      this.currentUser = await this.client.getMe();
      const sessionString = this.client.session.save();

      this.saveSessionData({
        sessionString,
        apiId: this.pendingAuth.apiId,
        apiHash: this.pendingAuth.apiHash,
        user: this.formatUser(this.currentUser)
      });

      this.setupEventListeners();

      return {
        success: true,
        user: this.formatUser(this.currentUser)
      };
    } catch (err) {
      if (err.message && err.message.includes('SESSION_PASSWORD_NEEDED')) {
        return {
          requires2FA: true,
          message: 'Two-step verification (2FA password) is enabled on this account.'
        };
      }
      throw err;
    }
  }

  async verify2FAPassword(password) {
    if (!this.client) {
      throw new Error('Client is not connected.');
    }

    await this.client.signInWithPassword(
      {
        apiId: this.pendingAuth.apiId,
        apiHash: this.pendingAuth.apiHash,
      },
      {
        password: password,
        onError: (err) => { throw err; }
      }
    );

    this.isAuthorized = true;
    this.currentUser = await this.client.getMe();
    const sessionString = this.client.session.save();

    this.saveSessionData({
      sessionString,
      apiId: this.pendingAuth.apiId,
      apiHash: this.pendingAuth.apiHash,
      user: this.formatUser(this.currentUser)
    });

    this.setupEventListeners();

    return {
      success: true,
      user: this.formatUser(this.currentUser)
    };
  }

  async getDialogs(limit = 40) {
    if (!this.isAuthorized || !this.client) {
      return [];
    }

    const dialogs = await this.client.getDialogs({ limit: limit });
    const results = [];

    for (const d of dialogs) {
      let title = d.name || d.title || 'Untitled Chat';
      let type = 'user';
      if (d.isGroup) type = 'group';
      else if (d.isChannel) type = 'channel';

      let lastMsgText = '';
      let lastMsgTime = '';
      if (d.message) {
        const doc = d.message.media?.document || d.message.document;
        const mime = doc?.mimeType || '';
        const isVoice = mime.startsWith('audio/') || mime.includes('ogg');
        if (isVoice) {
          lastMsgText = '🎤 Voice message';
        } else {
          lastMsgText = d.message.message || (d.message.media ? '📷 Photo / Media' : '');
        }
        if (d.message.date) {
          lastMsgTime = new Date(d.message.date * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }
      }

      const entityId = d.id ? d.id.toString() : null;
      let avatarDataUrl = entityId ? this.avatarCache.get(entityId) : null;

      if (!avatarDataUrl && d.entity) {
        try {
          const photoBuf = await this.client.downloadProfilePhoto(d.entity, { isBig: false });
          if (photoBuf && photoBuf.length > 0) {
            avatarDataUrl = `data:image/jpeg;base64,${photoBuf.toString('base64')}`;
            if (entityId) this.avatarCache.set(entityId, avatarDataUrl);
          }
        } catch (_) {}
      }

      results.push({
        id: d.id.toString(),
        name: title,
        type: type,
        unreadCount: d.unreadCount || 0,
        lastMessage: lastMsgText,
        lastMessageTime: lastMsgTime,
        avatar: avatarDataUrl || (type === 'channel' ? '📢' : (type === 'group' ? '👥' : '👤')),
        isPinned: d.pinned || false,
        isTelegramDirect: true
      });
    }

    return results;
  }

  async getMessages(chatId, limit = 50) {
    if (!this.isAuthorized || !this.client) {
      return [];
    }

    const messages = await this.client.getMessages(chatId, { limit: limit });
    const formatted = [];

    const chatIdStr = chatId ? chatId.toString() : '';
    const chatAvatar = this.avatarCache.get(chatIdStr) || null;

    for (const m of messages.reverse()) {
      const sender = m.sender;
      const senderName = sender ? (`${sender.firstName || ''} ${sender.lastName || ''}`.trim() || sender.username || 'User') : (m.out ? 'You' : 'Member');
      const senderId = sender ? sender.id.toString() : (m.out ? 'me' : 'other');
      const senderAvatar = (senderId && this.avatarCache.get(senderId)) || chatAvatar;

      let mediaDataUrl = null;
      let voiceDataUrl = null;
      let isVoice = false;

      const doc = m.media?.document || m.document;
      const docMime = doc?.mimeType || '';

      if (m.media) {
        if (m.photo || (docMime && docMime.startsWith('image/'))) {
          try {
            const buffer = await this.client.downloadMedia(m, { workers: 1 });
            if (buffer && buffer.length > 0) {
              const mime = m.photo ? 'image/jpeg' : (docMime || 'image/jpeg');
              mediaDataUrl = `data:${mime};base64,${buffer.toString('base64')}`;
            }
          } catch (err) {
            console.warn('Error downloading photo for message:', m.id, err.message);
          }
        } else if (docMime && (docMime.startsWith('audio/') || docMime.includes('ogg'))) {
          isVoice = true;
          try {
            const buffer = await this.client.downloadMedia(m, { workers: 1 });
            if (buffer && buffer.length > 0) {
              voiceDataUrl = `data:${docMime};base64,${buffer.toString('base64')}`;
            }
          } catch (err) {
            console.warn('Error downloading voice for message:', m.id, err.message);
          }
          if (!voiceDataUrl) {
            voiceDataUrl = 'voice_note.ogg';
          }
        }
      }

      formatted.push({
        id: 'tg_' + m.id,
        rawId: m.id,
        chatId: chatId,
        senderId: senderId,
        senderName: m.out ? 'You' : senderName,
        avatar: senderAvatar,
        text: m.message || (isVoice ? '' : ''),
        media: mediaDataUrl,
        voiceNote: isVoice ? (voiceDataUrl || 'voice_note.ogg') : null,
        timestamp: new Date(m.date * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        isOut: m.out || false,
        isTelegram: true
      });
    }

    return formatted;
  }

  async sendMessage(chatId, text, options = {}) {
    if (!this.isAuthorized || !this.client) {
      throw new Error('Telegram account is not connected');
    }

    const sendText = (text && text.trim().length > 0) ? text : (options.voiceNote ? '🎤 Voice message' : '🎤 Voice message');
    const res = await this.client.sendMessage(chatId, { message: sendText });
    return {
      id: 'tg_' + res.id,
      chatId: chatId,
      senderName: 'You',
      text: sendText,
      voiceNote: options.voiceNote || null,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      isOut: true
    };
  }

  async logout() {
    if (this.client) {
      try {
        await this.client.disconnect();
      } catch (e) {}
    }
    this.clearSessionData();
    return { success: true };
  }
}

export const telegramAccount = new TelegramAccountManager();
