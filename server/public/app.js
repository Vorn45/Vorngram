/* =========================================================
   TELEGRAM CLONE - CLIENT APP LOGIC
   WebSocket Messaging, MTProto Account Sync, WebRTC & Media
========================================================= */

function getAvatarGradient(str) {
    const gradients = [
        'linear-gradient(135deg, #e53935, #e35d5b)',
        'linear-gradient(135deg, #d81b60, #f06292)',
        'linear-gradient(135deg, #8e24aa, #ba68c8)',
        'linear-gradient(135deg, #5e35b1, #7e57c2)',
        'linear-gradient(135deg, #1e88e5, #42a5f5)',
        'linear-gradient(135deg, #00acc1, #26c6da)',
        'linear-gradient(135deg, #43a047, #66bb6a)',
        'linear-gradient(135deg, #fb8c00, #ffa726)',
        'linear-gradient(135deg, #00897b, #4db6ac)',
    ];
    let hash = 0;
    for (let i = 0; i < (str || '').length; i++) {
        hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }
    return gradients[Math.abs(hash) % gradients.length];
}

function getInitials(name) {
    if (!name) return 'TG';
    const words = name.trim().split(/\s+/);
    if (words.length >= 2 && words[0] && words[1]) {
        return (words[0][0] + words[1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
}

class ChatApplication {
    constructor() {
        this.ws = null;
        this.myUser = null;
        this.rooms = [];
        this.tgDialogs = [];
        this.onlineUsers = [];
        this.currentChatId = 'room-general';
        this.currentChatType = 'room'; // 'room', 'user', or 'telegram'
        this.activeChatObj = null;

        this.tgAccount = {
            isConnected: false,
            user: null
        };

        this.typingTimeout = null;
        this.isRecordingVoice = false;
        this.mediaRecorder = null;
        this.audioChunks = [];

        this.initDOM();
        this.connectWebSocket();
    }

    initDOM() {
        this.chatListEl = document.getElementById('chat-list');
        this.messagesListEl = document.getElementById('messages-list');
        this.messagesContainer = document.getElementById('messages-container');
        this.messageInput = document.getElementById('message-input');
        this.btnSendMessage = document.getElementById('btn-send-message');
        this.btnVoiceRecord = document.getElementById('btn-voice-record');
        this.btnAttachment = document.getElementById('btn-attachment');
        this.fileAttachmentInput = document.getElementById('file-attachment-input');
        this.typingBar = document.getElementById('typing-bar');
        this.typingText = document.getElementById('typing-text');
        this.activeChatTitle = document.getElementById('active-chat-title');
        this.activeChatSubtitle = document.getElementById('active-chat-subtitle');
        this.activeChatAvatar = document.getElementById('active-chat-avatar');

        // Call Buttons
        document.getElementById('btn-start-audio-call').onclick = () => this.initiateCall('audio');
        document.getElementById('btn-start-video-call').onclick = () => this.initiateCall('video');

        // Send Message Handlers
        this.btnSendMessage.onclick = () => this.sendMessage();
        this.messageInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            } else {
                this.sendTyping();
            }
        });

        // Auto-expand textarea
        this.messageInput.addEventListener('input', () => {
            this.messageInput.style.height = 'auto';
            this.messageInput.style.height = Math.min(100, this.messageInput.scrollHeight) + 'px';
        });

        // Search Bar
        document.getElementById('chat-search').addEventListener('input', (e) => {
            this.filterSearch(e.target.value);
        });

        // Profile Modal
        document.getElementById('btn-edit-profile').onclick = () => this.openProfileModal();
        document.getElementById('btn-cancel-profile').onclick = () => document.getElementById('profile-modal').classList.add('hidden');
        document.getElementById('btn-save-profile').onclick = () => this.saveProfile();

        // Telegram Account Connect Modal
        this.initTelegramConnectUI();

        // Fake Message & Chat Studio
        this.initFakeMessageStudio();

        // Direct Send to Telegram Modal
        this.initSendTelegramModal();

        // Chat Tabs Filtering
        document.querySelectorAll('.chat-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                document.querySelectorAll('.chat-tab').forEach(t => t.classList.remove('active'));
                tab.classList.add('active');
                this.renderChatList(tab.getAttribute('data-filter'));
            });
        });

        // File Attachment
        this.btnAttachment.onclick = () => this.fileAttachmentInput.click();
        this.fileAttachmentInput.addEventListener('change', (e) => this.handleFileSelect(e));

        // Voice Recording
        this.btnVoiceRecord.onclick = () => this.toggleVoiceRecording();

        // Mobile Back
        document.getElementById('btn-mobile-back').onclick = () => {
            document.getElementById('sidebar').classList.remove('mobile-hidden');
        };
    }

    initTelegramConnectUI() {
        const modal = document.getElementById('tg-login-modal');
        const openBtn = document.getElementById('btn-open-tg-login');
        const closeBtn = document.getElementById('btn-close-tg-modal');
        const doneBtn = document.getElementById('btn-tg-done');
        const sendCodeBtn = document.getElementById('btn-tg-send-code');
        const verifyCodeBtn = document.getElementById('btn-tg-verify-code');
        const verify2faBtn = document.getElementById('btn-tg-verify-2fa');
        const logoutBtn = document.getElementById('btn-tg-logout');
        const backToPhoneBtn = document.getElementById('btn-back-to-phone');
        const backToCodeBtn = document.getElementById('btn-back-to-code');

        openBtn.onclick = () => {
            this.showAuthError('');
            if (this.tgAccount.isConnected) {
                this.showAuthStep('connected');
                this.populateConnectedUI();
            } else {
                this.showAuthStep('phone');
            }
            modal.classList.remove('hidden');
        };

        closeBtn.onclick = () => modal.classList.add('hidden');
        doneBtn.onclick = () => modal.classList.add('hidden');

        backToPhoneBtn.onclick = () => this.showAuthStep('phone');
        backToCodeBtn.onclick = () => this.showAuthStep('code');

        sendCodeBtn.onclick = () => {
            const phone = document.getElementById('tg-phone-input').value.trim();
            const apiId = document.getElementById('tg-api-id-input').value.trim();
            const apiHash = document.getElementById('tg-api-hash-input').value.trim();

            if (!phone) {
                this.showAuthError('Please enter your phone number with country code (e.g. +855...)');
                return;
            }

            this.showAuthError('');
            document.getElementById('loader-send-code').classList.remove('hidden');
            sendCodeBtn.disabled = true;

            this.sendWS({
                type: 'tg-send-code',
                phone: phone,
                apiId: apiId,
                apiHash: apiHash
            });
        };

        verifyCodeBtn.onclick = () => {
            const code = document.getElementById('tg-code-input').value.trim();
            if (!code) {
                this.showAuthError('Please enter the 5-digit verification code.');
                return;
            }

            this.showAuthError('');
            document.getElementById('loader-verify-code').classList.remove('hidden');
            verifyCodeBtn.disabled = true;

            this.sendWS({
                type: 'tg-verify-code',
                code: code
            });
        };

        verify2faBtn.onclick = () => {
            const password = document.getElementById('tg-2fa-input').value;
            if (!password) {
                this.showAuthError('Please enter your 2FA password.');
                return;
            }

            this.showAuthError('');
            document.getElementById('loader-verify-2fa').classList.remove('hidden');
            verify2faBtn.disabled = true;

            this.sendWS({
                type: 'tg-verify-2fa',
                password: password
            });
        };

        logoutBtn.onclick = () => {
            if (confirm('Disconnect Telegram Account from this app?')) {
                this.sendWS({ type: 'tg-logout' });
            }
        };
    }

    showAuthStep(step) {
        document.getElementById('tg-step-phone').classList.add('hidden');
        document.getElementById('tg-step-code').classList.add('hidden');
        document.getElementById('tg-step-2fa').classList.add('hidden');
        document.getElementById('tg-step-connected').classList.add('hidden');

        document.getElementById(`tg-step-${step}`).classList.remove('hidden');
    }

    showAuthError(msg) {
        const el = document.getElementById('tg-auth-error');
        if (msg) {
            el.innerText = msg;
            el.classList.remove('hidden');
        } else {
            el.innerText = '';
            el.classList.add('hidden');
        }
    }

    populateConnectedUI() {
        if (!this.tgAccount.user) return;
        const u = this.tgAccount.user;
        document.getElementById('tg-acc-name').innerText = u.displayName || 'Telegram User';
        document.getElementById('tg-acc-username').innerText = u.username ? `@${u.username}` : '';
        document.getElementById('tg-acc-phone').innerText = u.phone ? `+${u.phone}` : '';
        document.getElementById('tg-acc-avatar').innerText = getInitials(u.displayName);
        document.getElementById('tg-acc-avatar').style.background = getAvatarGradient(u.displayName);
    }

    updateTelegramBadgeState() {
        const badgeBtn = document.getElementById('btn-open-tg-login');
        const badgeLabel = document.getElementById('tg-connect-status-label');
        if (this.tgAccount.isConnected) {
            badgeBtn.classList.add('connected');
            badgeLabel.innerText = this.tgAccount.user ? (this.tgAccount.user.username ? `@${this.tgAccount.user.username}` : 'Synced') : 'Connected';
            if (this.tgAccount.user) {
                document.getElementById('my-username').innerText = this.tgAccount.user.displayName || `@${this.tgAccount.user.username}`;
                document.getElementById('my-avatar').innerText = getInitials(this.tgAccount.user.displayName);
                document.getElementById('my-avatar').style.background = getAvatarGradient(this.tgAccount.user.displayName);
            }
        } else {
            badgeBtn.classList.remove('connected');
            badgeLabel.innerText = 'Connect';
        }
    }

    initFakeMessageStudio() {
        const modal = document.getElementById('fake-modal');
        const openBtn = document.getElementById('btn-open-fake-modal');
        const quickBtn = document.getElementById('btn-quick-fake');
        const closeBtn = document.getElementById('btn-close-fake-modal');
        const cancelMsgBtn = document.getElementById('btn-cancel-fake-msg');
        const cancelChatBtn = document.getElementById('btn-cancel-fake-chat');
        const submitMsgBtn = document.getElementById('btn-submit-fake-msg');
        const submitChatBtn = document.getElementById('btn-submit-fake-chat');
        const openBotBtn = document.getElementById('btn-open-bot-room');

        const showModal = (tabId = 'tab-fake-msg') => {
            const destLabel = document.getElementById('fake-dest-label');
            if (destLabel) {
                destLabel.innerText = this.activeChatTitle ? this.activeChatTitle.innerText.trim() : 'Current Chat';
            }
            document.querySelectorAll('.fake-tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.fake-tab-content').forEach(c => c.classList.add('hidden'));
            const activeBtn = document.querySelector(`.fake-tab-btn[data-tab="${tabId}"]`);
            if (activeBtn) activeBtn.classList.add('active');
            const activeContent = document.getElementById(tabId);
            if (activeContent) activeContent.classList.remove('hidden');

            modal.classList.remove('hidden');
        };

        const hideModal = () => modal.classList.add('hidden');

        if (openBtn) openBtn.onclick = () => showModal('tab-fake-msg');
        if (quickBtn) quickBtn.onclick = () => showModal('tab-fake-msg');
        if (closeBtn) closeBtn.onclick = hideModal;
        if (cancelMsgBtn) cancelMsgBtn.onclick = hideModal;
        if (cancelChatBtn) cancelChatBtn.onclick = hideModal;

        // Modal Tabs
        document.querySelectorAll('.fake-tab-btn').forEach(btn => {
            btn.onclick = () => {
                document.querySelectorAll('.fake-tab-btn').forEach(b => b.classList.remove('active'));
                document.querySelectorAll('.fake-tab-content').forEach(c => c.classList.add('hidden'));
                btn.classList.add('active');
                const tab = document.getElementById(btn.getAttribute('data-tab'));
                if (tab) tab.classList.remove('hidden');
            };
        });

        // Direction Toggle (Incoming vs Outgoing)
        let currentDir = 'in';
        const dirInBtn = document.getElementById('btn-dir-in');
        const dirOutBtn = document.getElementById('btn-dir-out');
        const senderSection = document.getElementById('fake-sender-section');

        if (dirInBtn && dirOutBtn) {
            dirInBtn.onclick = () => {
                currentDir = 'in';
                dirInBtn.classList.add('active');
                dirOutBtn.classList.remove('active');
                if (senderSection) senderSection.classList.remove('hidden');
            };
            dirOutBtn.onclick = () => {
                currentDir = 'out';
                dirOutBtn.classList.add('active');
                dirInBtn.classList.remove('active');
                if (senderSection) senderSection.classList.add('hidden');
            };
        }

        // Preset chips for sender
        document.querySelectorAll('.preset-chip').forEach(chip => {
            chip.onclick = () => {
                const name = chip.getAttribute('data-name');
                const avatar = chip.getAttribute('data-avatar');
                const isVer = chip.getAttribute('data-verified') === 'true';
                document.getElementById('fake-sender-name').value = name;
                document.getElementById('fake-sender-avatar').value = avatar;
                document.getElementById('fake-sender-verified').checked = isVer;
            };
        });

        // Preset chips for message template
        document.querySelectorAll('.preset-msg-chip').forEach(chip => {
            chip.onclick = () => {
                const text = chip.getAttribute('data-text');
                document.getElementById('fake-msg-text').value = text;
            };
        });

        // Open Bot Room
        if (openBotBtn) {
            openBotBtn.onclick = () => {
                hideModal();
                this.switchChat('room-bot', 'room', { name: '🤖 Secret Message Bot', id: 'room-bot', avatar: '🕵️' });
            };
        }

        // Submit Fake Message
        if (submitMsgBtn) {
            submitMsgBtn.onclick = () => {
                const text = document.getElementById('fake-msg-text').value.trim();
                if (!text) {
                    alert('Please enter message content.');
                    return;
                }

                const isOut = currentDir === 'out';
                const senderName = isOut ? (this.myUser?.username || 'Me') : (document.getElementById('fake-sender-name').value.trim() || 'Anonymous');
                const avatar = isOut ? (this.myUser?.avatar || '👨‍🚀') : (document.getElementById('fake-sender-avatar').value.trim() || '🎭');
                const isVerified = !isOut && document.getElementById('fake-sender-verified').checked;
                const timestamp = document.getElementById('fake-msg-time').value.trim() || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                const status = document.getElementById('fake-msg-status').value;
                const simMode = document.querySelector('input[name="sim-mode"]:checked')?.value || 'now';

                hideModal();
                const targetRoomId = this.currentChatId;

                if (simMode === 'delayed') {
                    // Realistic Simulation: Show typing indicator for 3 seconds then play sound and insert!
                    this.showTyping(senderName);
                    setTimeout(() => {
                        window.soundEngine?.playMessageSound();
                        this.sendWS({
                            type: 'fake-message',
                            roomId: targetRoomId,
                            senderName: senderName,
                            avatar: avatar,
                            text: text,
                            isOut: isOut,
                            isVerified: isVerified,
                            timestamp: timestamp,
                            status: status
                        });
                    }, 3000);
                } else {
                    // Instant injection
                    window.soundEngine?.playMessageSound();
                    this.sendWS({
                        type: 'fake-message',
                        roomId: targetRoomId,
                        senderName: senderName,
                        avatar: avatar,
                        text: text,
                        isOut: isOut,
                        isVerified: isVerified,
                        timestamp: timestamp,
                        status: status
                    });
                }
            };
        }

        // Submit Create Fake Chat
        if (submitChatBtn) {
            submitChatBtn.onclick = () => {
                const name = document.getElementById('fake-chat-name').value.trim();
                if (!name) {
                    alert('Please enter a chat or contact name.');
                    return;
                }
                const chatType = document.getElementById('fake-chat-type').value;
                const avatar = document.getElementById('fake-chat-avatar').value.trim() || '💬';
                const subtitle = document.getElementById('fake-chat-subtitle').value.trim() || 'online';
                const unreadCount = parseInt(document.getElementById('fake-chat-unread').value, 10) || 0;
                const isVerified = document.getElementById('fake-chat-verified').checked;
                const initialMsg = document.getElementById('fake-chat-initial-msg').value.trim();

                this.sendWS({
                    type: 'create-custom-room',
                    name: name,
                    chatType: chatType,
                    avatar: avatar,
                    subtitle: subtitle,
                    unreadCount: unreadCount,
                    isVerified: isVerified,
                    initialMessage: initialMsg
                });

                hideModal();
            };
        }
    }

    initSendTelegramModal() {
        const modal = document.getElementById('send-tg-modal');
        const openBtn = document.getElementById('btn-open-send-tg-modal');
        const closeBtn = document.getElementById('btn-close-send-tg-modal');
        const cancelBtn = document.getElementById('btn-cancel-send-tg');
        const submitBtn = document.getElementById('btn-submit-send-tg');
        const statusMsg = document.getElementById('send-tg-status-msg');
        const targetInput = document.getElementById('send-tg-target');
        const textInput = document.getElementById('send-tg-text');
        const btnAccount = document.getElementById('btn-send-as-account');
        const btnBot = document.getElementById('btn-send-as-bot');

        let senderType = 'account';

        const showModal = () => {
            if (statusMsg) statusMsg.classList.add('hidden');
            if (targetInput) targetInput.value = '';
            if (textInput) textInput.value = '';
            modal.classList.remove('hidden');
        };

        const hideModal = () => modal.classList.add('hidden');

        if (openBtn) openBtn.onclick = showModal;
        if (closeBtn) closeBtn.onclick = hideModal;
        if (cancelBtn) cancelBtn.onclick = hideModal;

        if (btnAccount && btnBot) {
            btnAccount.onclick = () => {
                senderType = 'account';
                btnAccount.classList.add('active');
                btnBot.classList.remove('active');
            };
            btnBot.onclick = () => {
                senderType = 'bot';
                btnBot.classList.add('active');
                btnAccount.classList.remove('active');
            };
        }

        if (submitBtn) {
            submitBtn.onclick = () => {
                const target = targetInput.value.trim();
                const text = textInput.value.trim();

                if (!target) {
                    statusMsg.innerText = 'Please enter a target @username or phone number.';
                    statusMsg.classList.remove('hidden');
                    return;
                }
                if (!text) {
                    statusMsg.innerText = 'Please enter message content.';
                    statusMsg.classList.remove('hidden');
                    return;
                }

                document.getElementById('loader-send-tg')?.classList.remove('hidden');
                submitBtn.disabled = true;

                this.sendWS({
                    type: 'tg-new-direct-message',
                    target: target,
                    text: text,
                    senderType: senderType
                });
            };
        }
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}`;

        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('Connected to Telegram WebSocket Server');
        };

        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.handleServerMessage(data);
            } catch (e) {
                console.error('Error parsing WS message:', e);
            }
        };

        this.ws.onclose = () => {
            console.warn('WebSocket connection closed. Reconnecting in 2s...');
            setTimeout(() => this.connectWebSocket(), 2000);
        };
    }

    sendWS(payload) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(payload));
        }
    }

    handleServerMessage(data) {
        switch (data.type) {
            case 'init-ack':
                this.myUser = data.user;
                this.rooms = data.rooms;
                if (data.tgAccount) {
                    this.tgAccount = data.tgAccount;
                    this.updateTelegramBadgeState();
                }
                if (!this.tgAccount.isConnected) {
                    document.getElementById('my-username').innerText = this.myUser.username;
                    document.getElementById('my-avatar').innerText = this.myUser.avatar;
                }
                this.renderChatList();
                this.renderMessages(data.history);
                break;

            case 'user-list':
                this.onlineUsers = data.users.filter(u => u.id !== this.myUser?.id);
                document.getElementById('online-count').innerText = this.onlineUsers.length;
                this.renderChatList();
                break;

            case 'room-history':
                this.renderMessages(data.history);
                break;

            case 'new-message':
                if (this.currentChatType === 'room' && data.message.roomId === this.currentChatId) {
                    this.appendMessage(data.message);
                    window.soundEngine?.playMessageSound();
                }
                break;

            case 'user-typing':
                if (data.roomId === this.currentChatId) {
                    this.showTyping(data.username);
                }
                break;

            case 'room-created':
                if (!this.rooms.find(r => r.id === data.room.id)) {
                    this.rooms.push(data.room);
                    this.renderChatList();
                    this.switchChat(data.room.id, 'room', data.room);
                }
                break;

            // --- Telegram MTProto Account Responses ---
            case 'tg-send-code-res':
                document.getElementById('loader-send-code').classList.add('hidden');
                document.getElementById('btn-tg-send-code').disabled = false;
                if (data.success) {
                    this.showAuthStep('code');
                    document.getElementById('tg-code-input').focus();
                } else {
                    this.showAuthError(data.error || 'Failed to send login code. Please check your phone number.');
                }
                break;

            case 'tg-verify-code-res':
                document.getElementById('loader-verify-code').classList.add('hidden');
                document.getElementById('btn-tg-verify-code').disabled = false;
                if (data.requires2FA) {
                    this.showAuthStep('2fa');
                    document.getElementById('tg-2fa-input').focus();
                } else if (data.success) {
                    this.tgAccount.isConnected = true;
                    this.tgAccount.user = data.user;
                    this.updateTelegramBadgeState();
                    this.showAuthStep('connected');
                    this.populateConnectedUI();
                } else {
                    this.showAuthError(data.error || 'Invalid code. Please try again.');
                }
                break;

            case 'tg-verify-2fa-res':
                document.getElementById('loader-verify-2fa').classList.add('hidden');
                document.getElementById('btn-tg-verify-2fa').disabled = false;
                if (data.success) {
                    this.tgAccount.isConnected = true;
                    this.tgAccount.user = data.user;
                    this.updateTelegramBadgeState();
                    this.showAuthStep('connected');
                    this.populateConnectedUI();
                } else {
                    this.showAuthError(data.error || 'Incorrect 2FA password.');
                }
                break;

            case 'tg-dialogs':
                this.tgDialogs = data.dialogs || [];
                document.getElementById('tg-chat-count').innerText = this.tgDialogs.length;
                this.renderChatList();
                break;

            case 'tg-messages':
                if (this.currentChatType === 'telegram' && this.currentChatId === data.chatId) {
                    this.renderMessages(data.messages);
                }
                break;

            case 'tg-message-sent':
                if (data.success && this.currentChatType === 'telegram') {
                    this.appendMessage(data.message);
                }
                break;

            case 'tg-direct-msg-sent': {
                const loader = document.getElementById('loader-send-tg');
                const submitBtn = document.getElementById('btn-submit-send-tg');
                const statusMsg = document.getElementById('send-tg-status-msg');
                const modal = document.getElementById('send-tg-modal');

                if (loader) loader.classList.add('hidden');
                if (submitBtn) submitBtn.disabled = false;

                if (data.success) {
                    if (modal) modal.classList.add('hidden');
                    window.soundEngine?.playMessageSound();
                    const tgTab = document.querySelector('.chat-tab[data-filter="telegram"]');
                    if (tgTab) tgTab.click();
                    alert(`✅ Message successfully sent to Telegram: ${data.target}`);
                } else {
                    if (statusMsg) {
                        statusMsg.innerText = data.error || 'Failed to send message. Please verify the username or phone number.';
                        statusMsg.classList.remove('hidden');
                    }
                }
                break;
            }

            case 'tg-live-message': {
                const msg = data.message;
                if (this.currentChatType === 'telegram' && this.currentChatId === msg.chatId) {
                    this.appendMessage({
                        id: msg.id,
                        senderName: msg.senderName,
                        text: msg.text,
                        timestamp: msg.timestamp,
                        isOut: msg.isOut
                    });
                    window.soundEngine?.playMessageSound();
                }
                const d = this.tgDialogs.find(x => x.id === msg.chatId);
                if (d) {
                    d.lastMessage = msg.text;
                    d.lastMessageTime = msg.timestamp;
                    if (this.currentChatId !== msg.chatId) {
                        d.unreadCount = (d.unreadCount || 0) + 1;
                    }
                    this.renderChatList();
                }
                break;
            }

            case 'tg-logout-res':
                this.tgAccount.isConnected = false;
                this.tgAccount.user = null;
                this.tgDialogs = [];
                document.getElementById('tg-chat-count').innerText = '0';
                this.updateTelegramBadgeState();
                this.showAuthStep('phone');
                this.renderChatList();
                this.switchChat('room-general', 'room');
                break;
        }
    }

    renderChatList(filter = 'all') {
        this.chatListEl.innerHTML = '';

        // 1. Telegram Synced Chats
        if (filter === 'all' || filter === 'telegram') {
            if (this.tgDialogs.length > 0) {
                const header = document.createElement('div');
                header.className = 'chat-section-header';
                header.innerHTML = `<span>✈️ TELEGRAM ACCOUNT CHATS</span> <span class="badge-count">${this.tgDialogs.length}</span>`;
                this.chatListEl.appendChild(header);

                this.tgDialogs.forEach(dialog => {
                    const item = document.createElement('div');
                    item.className = `chat-item ${this.currentChatId === dialog.id ? 'active' : ''}`;
                    item.onclick = () => this.switchChat(dialog.id, 'telegram', dialog);

                    const initials = getInitials(dialog.name);
                    const bgGrad = getAvatarGradient(dialog.name);

                    item.innerHTML = `
                        <div class="avatar chat-avatar" style="background: ${bgGrad};">${initials}</div>
                        <div class="chat-info">
                            <div class="chat-top-row">
                                <span class="chat-name">${this.escapeHTML(dialog.name)}</span>
                                <span class="chat-time">${dialog.lastMessageTime || ''}</span>
                            </div>
                            <div class="chat-bottom-row">
                                <span class="chat-snippet">${this.escapeHTML(dialog.lastMessage || 'No messages yet')}</span>
                                ${dialog.unreadCount > 0 ? `<span class="unread-badge">${dialog.unreadCount}</span>` : ''}
                            </div>
                        </div>
                    `;
                    this.chatListEl.appendChild(item);
                });
            } else if (filter === 'telegram') {
                const empty = document.createElement('div');
                empty.className = 'empty-chat-state';
                empty.innerHTML = `
                    <p style="text-align: center; padding: 24px; color: var(--tg-text-secondary); font-size: 13px;">
                        ${this.tgAccount.isConnected ? 'Loading Telegram chats...' : 'Connect your Telegram account to view chats here.'}
                    </p>
                `;
                this.chatListEl.appendChild(empty);
            }
        }

        // 2. Default Lounge / Channels & Mock Chats
        if (filter === 'all' || filter === 'channels' || filter === 'mock') {
            const isMockFilter = filter === 'mock';
            const header = document.createElement('div');
            header.className = 'chat-section-header';
            header.innerHTML = `<span>${isMockFilter ? '🎭 MOCK / FAKE CHATS' : '🌐 CHANNELS & LOUNGES'}</span>`;
            this.chatListEl.appendChild(header);

            const displayRooms = isMockFilter ? this.rooms.filter(r => r.isVerified || r.isCustom || r.type === 'bot' || r.id === 'room-durov' || r.id === 'room-crypto') : this.rooms;

            displayRooms.forEach(room => {
                const item = document.createElement('div');
                item.className = `chat-item ${this.currentChatId === room.id ? 'active' : ''}`;
                item.onclick = () => this.switchChat(room.id, 'room', room);

                const verifiedHtml = room.isVerified ? ` <span class="verified-badge" title="Verified">✓</span>` : '';

                item.innerHTML = `
                    <div class="avatar chat-avatar">${room.avatar}</div>
                    <div class="chat-info">
                        <div class="chat-top-row">
                            <span class="chat-name">${this.escapeHTML(room.name)}${verifiedHtml}</span>
                            <span class="chat-type-badge">${room.type.toUpperCase()}</span>
                        </div>
                        <div class="chat-bottom-row">
                            <span class="chat-snippet">${room.members ? room.members.toLocaleString() + ' members' : (room.subtitle || 'Active')}</span>
                        </div>
                    </div>
                `;
                this.chatListEl.appendChild(item);
            });
        }

        // 3. Online Web Users (for direct WebRTC calls)
        if (filter === 'all' || filter === 'direct') {
            const header = document.createElement('div');
            header.className = 'chat-section-header';
            header.innerHTML = `<span>👥 WEB CALL PEERS (${this.onlineUsers.length})</span>`;
            this.chatListEl.appendChild(header);

            this.onlineUsers.forEach(user => {
                const item = document.createElement('div');
                item.className = `chat-item direct-user-item ${this.currentChatId === user.id ? 'active' : ''}`;
                item.onclick = () => this.switchChat(user.id, 'user', user);

                item.innerHTML = `
                    <div class="avatar chat-avatar">${user.avatar}</div>
                    <div class="chat-info">
                        <div class="chat-top-row">
                            <span class="chat-name">${user.username}</span>
                            <span class="online-indicator-dot"></span>
                        </div>
                        <div class="chat-bottom-row">
                            <span class="chat-snippet">Click to call or message</span>
                        </div>
                    </div>
                `;
                this.chatListEl.appendChild(item);
            });
        }
    }

    switchChat(id, type, obj) {
        this.currentChatId = id;
        this.currentChatType = type;
        this.activeChatObj = obj;

        // Update header UI
        if (type === 'telegram') {
            this.activeChatTitle.innerText = obj.name;
            this.activeChatSubtitle.innerText = obj.type === 'channel' ? 'Telegram Channel' : (obj.type === 'group' ? 'Telegram Group' : 'Telegram Private Chat');
            this.activeChatAvatar.innerText = getInitials(obj.name);
            this.activeChatAvatar.style.background = getAvatarGradient(obj.name);
            
            this.messagesListEl.innerHTML = '<div style="text-align:center; padding: 20px; color: var(--tg-text-secondary);">Loading Telegram messages...</div>';
            this.sendWS({
                type: 'tg-get-messages',
                chatId: id,
                limit: 50
            });
        } else if (type === 'room') {
            const room = this.rooms.find(r => r.id === id) || obj;
            const verifiedHtml = room.isVerified ? ` <span class="verified-badge" title="Verified">✓</span>` : '';
            this.activeChatTitle.innerHTML = `${this.escapeHTML(room.name)}${verifiedHtml}`;
            this.activeChatSubtitle.innerText = room.members ? `${room.members.toLocaleString()} members` : (room.subtitle || 'Telegram Group');
            this.activeChatAvatar.innerText = room.avatar;
            this.activeChatAvatar.style.background = 'linear-gradient(135deg, #2481cc, #54a5e5)';
            this.sendWS({
                type: 'join-room',
                roomId: id
            });
        } else if (type === 'user') {
            const user = this.onlineUsers.find(u => u.id === id) || obj;
            this.activeChatTitle.innerText = user.username;
            this.activeChatSubtitle.innerText = 'Online Web User';
            this.activeChatAvatar.innerText = user.avatar;
            this.activeChatAvatar.style.background = 'linear-gradient(135deg, #43a047, #66bb6a)';
        }

        // On mobile, hide sidebar
        document.getElementById('sidebar').classList.add('mobile-hidden');
        this.renderChatList();
    }

    renderMessages(messages = []) {
        this.messagesListEl.innerHTML = '';
        messages.forEach(msg => this.appendMessage(msg));
        this.scrollToBottom();
    }

    appendMessage(msg) {
        const isMe = msg.isOut || (this.myUser && msg.senderId === this.myUser.id);
        const bubble = document.createElement('div');
        bubble.className = `message-bubble ${isMe ? 'message-out' : 'message-in'} ${msg.isSystem ? 'message-system' : ''}`;

        let mediaHtml = '';
        if (msg.media) {
            mediaHtml = `<div class="msg-media-wrap"><img src="${msg.media}" alt="Attachment" class="msg-media-img" onclick="window.open('${msg.media}')" /></div>`;
        }
        if (msg.voiceNote) {
            mediaHtml += `
                <div class="msg-audio-wrap">
                    <audio controls src="${msg.voiceNote}" class="voice-note-player"></audio>
                </div>
            `;
        }

        const verifiedHtml = msg.isVerified ? `<span class="verified-badge" title="Verified">✓</span>` : '';
        const statusHtml = isMe ? (msg.status === 'sent' ? '<span class="msg-status-ticks">✓</span>' : (msg.status === 'read' ? '<span class="msg-status-ticks" style="color: #64b5f6;">✓✓</span>' : '<span class="msg-status-ticks">✓✓</span>')) : '';

        bubble.innerHTML = `
            ${!isMe && !msg.isSystem ? `<div class="message-sender-name">${this.escapeHTML(msg.senderName || 'Member')} ${verifiedHtml}</div>` : ''}
            ${mediaHtml}
            ${msg.text ? `<div class="message-text">${this.formatMessageText(msg.text)}</div>` : ''}
            <div class="message-meta">
                <span class="message-time">${msg.timestamp || ''}</span>
                ${statusHtml}
            </div>
        `;

        this.messagesListEl.appendChild(bubble);
        this.scrollToBottom();
    }

    sendMessage() {
        const text = this.messageInput.value.trim();
        if (!text && !this.selectedMedia) return;

        if (this.currentChatType === 'telegram') {
            this.sendWS({
                type: 'tg-send-message',
                chatId: this.currentChatId,
                text: text
            });
        } else {
            this.sendWS({
                type: 'send-message',
                roomId: this.currentChatId,
                text: text,
                media: this.selectedMedia || null
            });
        }

        this.messageInput.value = '';
        this.messageInput.style.height = 'auto';
        this.selectedMedia = null;
    }

    sendTyping() {
        if (this.typingTimeout) clearTimeout(this.typingTimeout);
        this.sendWS({
            type: 'typing',
            roomId: this.currentChatId
        });
        this.typingTimeout = setTimeout(() => {}, 2000);
    }

    showTyping(username) {
        this.typingText.innerText = `${username} is typing...`;
        this.typingBar.classList.remove('hidden');
        setTimeout(() => {
            this.typingBar.classList.add('hidden');
        }, 2500);
    }

    scrollToBottom() {
        this.messagesContainer.scrollTop = this.messagesContainer.scrollHeight;
    }

    initiateCall(callType) {
        if (this.currentChatType === 'user') {
            window.webrtcManager?.startCall(this.currentChatId, this.activeChatObj?.username || 'User', this.activeChatObj?.avatar || '👤', callType);
        } else if (this.currentChatType === 'telegram') {
            const callRoomId = 'call_' + this.currentChatId;
            const origin = window.location.origin;
            const callLink = `${origin}?call=${callRoomId}`;

            // Open the Call Window immediately with local Audio / Video
            window.webrtcManager?.startRoomCall(callRoomId, this.activeChatTitle.innerText, callType);

            // Send 1-click Join Call invite into the active Telegram chat
            this.sendWS({
                type: 'tg-send-message',
                chatId: this.currentChatId,
                text: `📞 Incoming ${callType === 'video' ? 'HD Video' : 'Voice'} Call! Click below to join:\n${callLink}`
            });
        } else {
            const callRoomId = 'room_' + this.currentChatId;
            window.webrtcManager?.startRoomCall(callRoomId, this.activeChatTitle.innerText, callType);
        }
    }

    openProfileModal() {
        document.getElementById('input-username').value = this.myUser?.username || '';
        document.getElementById('profile-modal').classList.remove('hidden');
    }

    saveProfile() {
        const username = document.getElementById('input-username').value.trim();
        if (username) {
            this.sendWS({
                type: 'set-profile',
                username: username
            });
        }
        document.getElementById('profile-modal').classList.add('hidden');
    }

    handleFileSelect(e) {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (uploadEvent) => {
            this.selectedMedia = uploadEvent.target.result;
            this.sendMessage();
        };
        reader.readAsDataURL(file);
    }

    async toggleVoiceRecording() {
        if (this.isRecordingVoice) {
            this.mediaRecorder.stop();
            this.btnVoiceRecord.classList.remove('recording');
            this.isRecordingVoice = false;
        } else {
            try {
                const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                this.mediaRecorder = new MediaRecorder(stream);
                this.audioChunks = [];

                this.mediaRecorder.ondataavailable = (e) => this.audioChunks.push(e.data);
                this.mediaRecorder.onstop = () => {
                    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
                    const reader = new FileReader();
                    reader.onloadend = () => {
                        this.sendWS({
                            type: 'send-message',
                            roomId: this.currentChatId,
                            voiceNote: reader.result
                        });
                    };
                    reader.readAsDataURL(audioBlob);
                    stream.getTracks().forEach(t => t.stop());
                };

                this.mediaRecorder.start();
                this.btnVoiceRecord.classList.add('recording');
                this.isRecordingVoice = true;
            } catch (err) {
                alert('Microphone access denied: ' + err.message);
            }
        }
    }

    filterSearch(query) {
        const q = query.toLowerCase().trim();
        if (!q) {
            this.renderChatList();
            return;
        }

        document.querySelectorAll('.chat-item').forEach(item => {
            const name = item.querySelector('.chat-name')?.innerText.toLowerCase() || '';
            const snippet = item.querySelector('.chat-snippet')?.innerText.toLowerCase() || '';
            if (name.includes(q) || snippet.includes(q)) {
                item.style.display = 'flex';
            } else {
                item.style.display = 'none';
            }
        });
    }

    escapeHTML(str) {
        if (!str) return '';
        return str.replace(/[&<>'"]/g, 
            tag => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[tag] || tag)
        );
    }

    formatMessageText(text) {
        const escaped = this.escapeHTML(text);
        return escaped.replace(/\n/g, '<br>');
    }
}

// Start application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.chatApp = new ChatApplication();
});
