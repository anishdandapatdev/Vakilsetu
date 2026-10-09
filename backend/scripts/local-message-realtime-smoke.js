// Runs only against the local developer API with reserved test identities.
require('dotenv').config();
const { createHash, randomUUID } = require('node:crypto');

const base = 'http://127.0.0.1:8080/v1';

async function api(path, method = 'GET', body, token) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  if (!response.ok) throw new Error(`${method} ${path}: HTTP ${response.status}`);
  return response.status === 204 ? null : response.json();
}

async function signIn(phone) {
  const challenge = await api('/auth/otp/request', 'POST', { phone });
  return api('/auth/otp/verify', 'POST', {
    challengeId: challenge.challengeId,
    code: process.env.DEVELOPMENT_OTP_CODE || '123456',
    platform: 'web',
    publicIdentityKey: Buffer.from(Array.from({ length: 32 }, (_, i) => i + 1)).toString('base64'),
  });
}

async function main() {
  if (process.env.NODE_ENV !== 'development') {
    throw new Error('Local smoke test requires NODE_ENV=development.');
  }
  const sender = await signIn('+919000000004');
  const receiver = await signIn('+919000000005');
  const direct = await api('/conversations/direct', 'POST', {
    peerAccountId: receiver.accountId,
  }, sender.accessToken);
  const socket = new WebSocket('ws://127.0.0.1:8080/socket.io/?EIO=4&transport=websocket');
  try {
    let resolveNotification;
    let rejectNotification;
    const notification = new Promise((resolve, reject) => {
      resolveNotification = resolve;
      rejectNotification = reject;
    });
    const connected = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('socket_connect_timeout')), 5000);
      socket.addEventListener('message', (message) => {
        const packet = String(message.data);
        if (packet.startsWith('0')) {
          socket.send(`40/realtime,${JSON.stringify({ accessToken: receiver.accessToken })}`);
        } else if (packet === '2') {
          socket.send('3');
        } else if (packet.startsWith('40/realtime,')) {
          clearTimeout(timeout);
          resolve();
        } else if (packet.startsWith('42/realtime,')) {
          const [event, payload] = JSON.parse(packet.slice('42/realtime,'.length));
          if (event === 'sync:available') resolveNotification(payload);
        }
      });
      socket.addEventListener('error', reject, { once: true });
    });
    await connected;
    const timeout = setTimeout(() => rejectNotification(new Error('realtime_delivery_timeout')), 5000);
    const messageInput = {
      clientMessageId: randomUUID(),
      body: 'Local realtime smoke test',
    };
    const messagePath = `/conversations/${direct.conversationId}/messages`;
    const sent = await api(messagePath, 'POST', messageInput, sender.accessToken);
    const event = await notification.finally(() => clearTimeout(timeout));
    if (event.eventId !== sent.id) throw new Error('wrong_realtime_event');
    const history = await api(messagePath, 'GET', undefined, receiver.accessToken);
    if (!history.items.some((item) => item.id === sent.id)) {
      throw new Error('not_in_recipient_history');
    }
    const repeated = await api(messagePath, 'POST', messageInput, sender.accessToken);
    if (repeated.id !== sent.id) throw new Error('duplicate_send_created_second_message');
    const read = await api(`${messagePath}/read`, 'POST', {
      throughMessageId: sent.id,
    }, receiver.accessToken);
    if (!read.read) throw new Error('read_receipt_not_accepted');
    const senderHistory = await api(messagePath, 'GET', undefined, sender.accessToken);
    const observed = senderHistory.items.find((item) => item.id === sent.id);
    if (observed?.readCount !== 1) {
      throw new Error(`read_receipt_not_visible_to_sender: read=${observed?.readCount ?? 'missing'} recipients=${observed?.recipientCount ?? 'missing'} delivered=${observed?.deliveredCount ?? 'missing'}`);
    }

    const groupTitle = 'VakilSetu Local Messaging Smoke Test';
    const conversations = await api('/conversations', 'GET', undefined, sender.accessToken);
    const existingGroup = conversations.items.find((item) =>
      item.kind === 'private_group' && item.title === groupTitle);
    const groupId = existingGroup
      ? existingGroup.id
      : (await api('/conversations/groups', 'POST', {
        title: groupTitle,
        memberAccountIds: [receiver.accountId],
      }, sender.accessToken)).conversationId;
    if (existingGroup) {
      await api(`/conversations/${groupId}/members`, 'PATCH', {
        accountId: receiver.accountId,
        action: 'add',
      }, sender.accessToken);
    }
    const groupPath = `/conversations/${groupId}/messages`;
    const groupMessage = await api(groupPath, 'POST', {
      clientMessageId: randomUUID(),
      body: 'Local group access smoke test',
    }, sender.accessToken);
    const groupHistory = await api(groupPath, 'GET', undefined, receiver.accessToken);
    if (!groupHistory.items.some((item) => item.id === groupMessage.id)) {
      throw new Error('group_message_not_in_member_history');
    }
    await api(`/conversations/${groupId}/members`, 'PATCH', {
      accountId: receiver.accountId,
      action: 'remove',
    }, sender.accessToken);
    const removedResponse = await fetch(`${base}${groupPath}`, {
      headers: { authorization: `Bearer ${receiver.accessToken}` },
    });
    if (removedResponse.status !== 403) {
      throw new Error(`removed_group_member_access_status_${removedResponse.status}`);
    }

    const png = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lXcAAAAASUVORK5CYII=',
      'base64',
    );
    const sha256 = createHash('sha256').update(png).digest('hex');
    const initiated = await api(`/conversations/${direct.conversationId}/server-attachments`,
      'POST', {
        filename: 'local-smoke-test.png',
        contentType: 'image/png',
        byteSize: png.length,
        sha256,
      }, sender.accessToken);
    const upload = await fetch(initiated.upload.url, {
      method: 'PUT',
      headers: {
        'content-type': 'image/png',
        'x-amz-checksum-sha256': Buffer.from(sha256, 'hex').toString('base64'),
      },
      body: png,
    });
    if (!upload.ok) throw new Error(`attachment_upload_status_${upload.status}`);
    const completed = await api(`/server-attachments/${initiated.attachmentId}/complete`,
      'POST', {}, sender.accessToken);
    if (completed.status !== 'available') throw new Error('attachment_not_available');
    const attachmentMessage = await api(messagePath, 'POST', {
      clientMessageId: randomUUID(),
      body: 'Local attachment smoke test',
      attachmentId: initiated.attachmentId,
    }, sender.accessToken);
    if (!attachmentMessage.id) throw new Error('attachment_message_not_created');
    const download = await api(`/server-attachments/${initiated.attachmentId}/download`,
      'GET', undefined, receiver.accessToken);
    const downloaded = await fetch(download.url);
    if (!downloaded.ok || createHash('sha256').update(Buffer.from(await downloaded.arrayBuffer()))
      .digest('hex') !== sha256) throw new Error('attachment_download_checksum_mismatch');
    console.log(JSON.stringify({
      realtimeDelivered: true,
      recipientHistoryMatched: true,
      duplicateSendProtected: true,
      readReceiptVisible: true,
      groupMemberHistoryMatched: true,
      removedMemberDenied: true,
      attachmentRoundTripMatched: true,
    }));
  } finally {
    socket.close();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
