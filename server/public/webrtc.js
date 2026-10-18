/* =========================================================
   TELEGRAM CLONE - WEBRTC VOICE & VIDEO CALL MANAGER
   Peer-to-Peer Real-Time Audio/Video & Screen Sharing
========================================================= */

const RTC_CONFIG = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        { urls: 'stun:stun2.l.google.com:19302' }
    ]
};

class WebRTCManager {
    constructor() {
        this.peerConnection = null;
        this.localStream = null;
        this.remoteStream = null;
        this.screenStream = null;

        this.currentCallTargetId = null;
        this.currentCallTargetName = null;
        this.currentCallType = 'video'; // 'audio' or 'video'
        this.isCallActive = false;
        this.callStartTime = 0;
        this.callTimerInterval = null;

        // Media Toggles
        this.isMicMuted = false;
        this.isCamOff = false;
        this.isSharingScreen = false;

        this.initDOM();
    }

    initDOM() {
        this.localVideo = document.getElementById('local-video');
        this.remoteVideo = document.getElementById('remote-video');
        this.callModal = document.getElementById('call-modal');
        this.callStatusLabel = document.getElementById('call-status-label');
        this.callTimerEl = document.getElementById('call-timer');
        this.callPeerNameEl = document.getElementById('call-peer-name');
        this.callPeerAvatarEl = document.getElementById('call-peer-avatar');
        this.remoteAudioPlaceholder = document.getElementById('remote-audio-placeholder');
        this.remoteAudioName = document.getElementById('remote-audio-name');
        this.remoteCallAvatarBig = document.getElementById('remote-call-avatar-big');
        this.localCamOffBadge = document.getElementById('local-cam-off-badge');

        // Control Buttons
        document.getElementById('btn-toggle-mic').onclick = () => this.toggleMic();
        document.getElementById('btn-toggle-cam').onclick = () => this.toggleCam();
        document.getElementById('btn-share-screen').onclick = () => this.toggleScreenShare();
        document.getElementById('btn-end-call').onclick = () => this.endCall(true);
    }

    async startCall(targetUserId, targetUserName, targetUserAvatar, callType = 'video') {
        this.currentCallTargetId = targetUserId;
        this.currentCallTargetName = targetUserName;
        this.currentCallType = callType;

        this.showCallModal(targetUserName, targetUserAvatar, 'CALLING...');
        window.soundEngine?.startOutgoingRingtone();

        try {
            const constraints = {
                audio: true,
                video: callType === 'video' ? { width: { ideal: 1280 }, height: { ideal: 720 } } : false
            };

            this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
            this.localVideo.srcObject = this.localStream;

            this.createPeerConnection();

            this.localStream.getTracks().forEach(track => {
                this.peerConnection.addTrack(track, this.localStream);
            });

            const offer = await this.peerConnection.createOffer();
            await this.peerConnection.setLocalDescription(offer);

            window.chatApp.sendWS({
                type: 'call-user',
                targetUserId: targetUserId,
                callType: callType,
                offer: offer
            });

        } catch (err) {
            console.error('Failed to get user media for calling:', err);
            this.showCallModal(targetUserName, targetUserAvatar, 'MEDIA PERMISSION DENIED');
            setTimeout(() => this.endCall(false), 2500);
        }
    }

    async startRoomCall(roomId, roomName, callType = 'video') {
        this.currentCallTargetId = roomId;
        this.currentCallTargetName = roomName;
        this.currentCallType = callType;

        this.showCallModal(roomName, '📞', 'STARTING VOICE/VIDEO CALL...');
        window.soundEngine?.stopRingtones();

        try {
            const constraints = {
                audio: true,
                video: callType === 'video' ? { width: { ideal: 1280 }, height: { ideal: 720 } } : false
            };

            this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
            this.localVideo.srcObject = this.localStream;

            this.onCallConnected();
            this.callStatusLabel.innerText = 'CALL ACTIVE (WAITING FOR PEERS)';

            if (callType === 'audio') {
                this.remoteAudioPlaceholder.classList.remove('hidden');
                this.remoteAudioName.innerText = `${roomName} (Voice Active)`;
            } else {
                this.remoteAudioPlaceholder.classList.add('hidden');
            }
        } catch (err) {
            console.error('Failed to get microphone/camera:', err);
            alert('Please allow Microphone / Camera permission in your browser to start the call.');
            this.endCall(false);
        }
    }

    async handleIncomingCall(data) {
        const dialog = document.getElementById('incoming-call-dialog');
        document.getElementById('inc-caller-name').innerText = data.callerName;
        document.getElementById('inc-caller-avatar').innerText = data.callerAvatar;
        document.getElementById('inc-call-type').innerText = `Incoming ${data.callType === 'video' ? '📹 Video' : '📞 Voice'} Call`;
        dialog.classList.remove('hidden');

        window.soundEngine?.startIncomingRingtone();

        document.getElementById('btn-accept-call').onclick = async () => {
            dialog.classList.add('hidden');
            window.soundEngine?.stopRingtones();
            await this.acceptCall(data);
        };

        document.getElementById('btn-decline-call').onclick = () => {
            dialog.classList.add('hidden');
            window.soundEngine?.stopRingtones();
            window.chatApp.sendWS({
                type: 'call-reject',
                callerId: data.callerId,
                reason: 'declined'
            });
        };
    }

    async acceptCall(data) {
        this.currentCallTargetId = data.callerId;
        this.currentCallTargetName = data.callerName;
        this.currentCallType = data.callType;

        this.showCallModal(data.callerName, data.callerAvatar, 'CONNECTING...');

        try {
            const constraints = {
                audio: true,
                video: data.callType === 'video' ? { width: { ideal: 1280 }, height: { ideal: 720 } } : false
            };

            this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
            this.localVideo.srcObject = this.localStream;

            this.createPeerConnection();

            this.localStream.getTracks().forEach(track => {
                this.peerConnection.addTrack(track, this.localStream);
            });

            await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data.offer));
            const answer = await this.peerConnection.createAnswer();
            await this.peerConnection.setLocalDescription(answer);

            window.chatApp.sendWS({
                type: 'call-answer',
                callerId: data.callerId,
                answer: answer
            });

            this.onCallConnected();

        } catch (err) {
            console.error('Error accepting call:', err);
            this.endCall(true);
        }
    }

    async handleCallAccepted(data) {
        try {
            await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data.answer));
            this.onCallConnected();
        } catch (err) {
            console.error('Error setting remote description on accept:', err);
        }
    }

    handleCallRejected(data) {
        this.callStatusLabel.innerText = `CALL DECLINED (${data.reason.toUpperCase()})`;
        window.soundEngine?.playCallEnded();
        setTimeout(() => this.endCall(false), 2000);
    }

    async handleIceCandidate(data) {
        try {
            if (this.peerConnection && data.candidate) {
                await this.peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate));
            }
        } catch (err) {
            console.error('Error adding ICE candidate:', err);
        }
    }

    createPeerConnection() {
        this.peerConnection = new RTCPeerConnection(RTC_CONFIG);

        this.peerConnection.onicecandidate = (event) => {
            if (event.candidate && this.currentCallTargetId) {
                window.chatApp.sendWS({
                    type: 'ice-candidate',
                    targetUserId: this.currentCallTargetId,
                    candidate: event.candidate
                });
            }
        };

        this.peerConnection.ontrack = (event) => {
            this.remoteStream = event.streams[0];
            this.remoteVideo.srcObject = this.remoteStream;

            if (this.currentCallType === 'video') {
                this.remoteVideo.classList.remove('hidden');
                this.remoteAudioPlaceholder.classList.add('hidden');
            } else {
                this.remoteVideo.classList.add('hidden');
                this.remoteAudioPlaceholder.classList.remove('hidden');
            }
        };

        this.peerConnection.onconnectionstatechange = () => {
            if (this.peerConnection.connectionState === 'connected') {
                this.onCallConnected();
            } else if (this.peerConnection.connectionState === 'disconnected' || this.peerConnection.connectionState === 'failed') {
                this.endCall(false);
            }
        };
    }

    onCallConnected() {
        window.soundEngine?.playCallConnected();
        this.callStatusLabel.innerText = 'ENCRYPTED WEBRTC HD';
        this.isCallActive = true;
        this.callStartTime = Date.now();

        if (this.callTimerInterval) clearInterval(this.callTimerInterval);
        this.callTimerInterval = setInterval(() => {
            const elapsed = Math.floor((Date.now() - this.callStartTime) / 1000);
            const m = Math.floor(elapsed / 60).toString().padStart(2, '0');
            const s = (elapsed % 60).toString().padStart(2, '0');
            this.callTimerEl.innerText = `${m}:${s}`;
        }, 1000);
    }

    showCallModal(name, avatar, status) {
        this.callPeerNameEl.innerText = name;
        this.callPeerAvatarEl.innerText = avatar;
        this.remoteCallAvatarBig.innerText = avatar;
        this.remoteAudioName.innerText = name;
        this.callStatusLabel.innerText = status;
        this.callTimerEl.innerText = '00:00';

        if (this.currentCallType === 'video') {
            this.remoteVideo.classList.remove('hidden');
            this.remoteAudioPlaceholder.classList.add('hidden');
        } else {
            this.remoteVideo.classList.add('hidden');
            this.remoteAudioPlaceholder.classList.remove('hidden');
        }

        this.callModal.classList.remove('hidden');
    }

    toggleMic() {
        if (!this.localStream) return;
        const audioTrack = this.localStream.getAudioTracks()[0];
        if (audioTrack) {
            audioTrack.enabled = !audioTrack.enabled;
            this.isMicMuted = !audioTrack.enabled;
            const btn = document.getElementById('btn-toggle-mic');
            const icon = document.getElementById('mic-icon');
            btn.classList.toggle('active-off', this.isMicMuted);
            icon.innerText = this.isMicMuted ? '🔇' : '🎙️';
        }
    }

    toggleCam() {
        if (!this.localStream) return;
        const videoTrack = this.localStream.getVideoTracks()[0];
        if (videoTrack) {
            videoTrack.enabled = !videoTrack.enabled;
            this.isCamOff = !videoTrack.enabled;
            const btn = document.getElementById('btn-toggle-cam');
            const icon = document.getElementById('cam-icon');
            btn.classList.toggle('active-off', this.isCamOff);
            icon.innerText = this.isCamOff ? '🚫' : '📹';
            this.localCamOffBadge.classList.toggle('hidden', !this.isCamOff);
        }
    }

    async toggleScreenShare() {
        if (!this.isSharingScreen) {
            try {
                this.screenStream = await navigator.mediaDevices.getDisplayMedia({ video: true });
                const screenTrack = this.screenStream.getVideoTracks()[0];

                const sender = this.peerConnection?.getSenders().find(s => s.track && s.track.kind === 'video');
                if (sender) {
                    sender.replaceTrack(screenTrack);
                }

                this.localVideo.srcObject = this.screenStream;
                this.isSharingScreen = true;

                screenTrack.onended = () => {
                    this.stopScreenShare();
                };
            } catch (err) {
                console.warn('Screen share cancelled:', err);
            }
        } else {
            this.stopScreenShare();
        }
    }

    stopScreenShare() {
        if (this.screenStream) {
            this.screenStream.getTracks().forEach(t => t.stop());
            this.screenStream = null;
        }
        if (this.localStream) {
            const videoTrack = this.localStream.getVideoTracks()[0];
            const sender = this.peerConnection?.getSenders().find(s => s.track && s.track.kind === 'video');
            if (sender && videoTrack) {
                sender.replaceTrack(videoTrack);
            }
            this.localVideo.srcObject = this.localStream;
        }
        this.isSharingScreen = false;
    }

    endCall(notifyPeer = true) {
        window.soundEngine?.stopRingtones();
        window.soundEngine?.playCallEnded();

        if (notifyPeer && this.currentCallTargetId) {
            window.chatApp.sendWS({
                type: 'end-call',
                targetUserId: this.currentCallTargetId
            });
        }

        if (this.localStream) {
            this.localStream.getTracks().forEach(track => track.stop());
            this.localStream = null;
        }

        if (this.screenStream) {
            this.screenStream.getTracks().forEach(track => track.stop());
            this.screenStream = null;
        }

        if (this.peerConnection) {
            this.peerConnection.close();
            this.peerConnection = null;
        }

        if (this.callTimerInterval) {
            clearInterval(this.callTimerInterval);
            this.callTimerInterval = null;
        }

        this.isCallActive = false;
        this.currentCallTargetId = null;
        this.currentCallTargetName = null;
        this.callModal.classList.add('hidden');
    }
}

document.addEventListener('DOMContentLoaded', () => {
    window.webrtcManager = new WebRTCManager();
});
