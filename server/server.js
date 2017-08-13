import { request, createServer } from 'http';

import WebSocket, { Server } from 'ws';
import express from 'express';

const port = process.env.PORT || 8080;

const baseOptions = {
  method: 'GET',
  socketPath: '/var/run/docker.sock',
};

// Docker API integration

const dockerAPIRequest = path => {
  return new Promise((res, rej) => {
    let buffer = '';

    const r = request({ ...baseOptions, path }, response => {
      response.on('data', chunk => (buffer = buffer + chunk));
      response.on('end', () => res(buffer));
    });

    r.on('error', rej);

    r.end();
  });
};

const fetchData = () =>
  Promise.all([
    dockerAPIRequest('/nodes').then(JSON.parse),
    dockerAPIRequest('/services').then(JSON.parse),
    dockerAPIRequest('/networks').then(JSON.parse),
    dockerAPIRequest('/tasks').then(JSON.parse),
  ]).then(([nodes, services, networks, tasks]) => ({
    nodes,
    services,
    networks,
    tasks,
  }));

// WebSocket pub-sub

const publish = (listeners, data) => {
  listeners.forEach(listener => {
    if (listener.readyState !== WebSocket.OPEN) return;

    listener.send(JSON.stringify(data, null, 2));
  });
};

const subscribe = (listeners, newListener) => {
  return listeners.concat([newListener]);
};

const unsubscribe = (listeners, listener) => {
  const id = listeners.indexOf(listener);
  if (id < 0) return listeners;

  return [].concat(listeners).splice(id, 1);
};

const dropClosed = listeners => {
  return listeners.filter(ws => ws.readyState === WebSocket.OPEN);
};

// set up the application

const app = express();

app.use(express.static('client'));
app.get('/_health', (req, res) => res.end());
app.get('/data', (req, res) => {
  fetchData().then(it => res.send(it)).catch(e => res.send(e.toString()));
});

// start the polling

let listeners = [];
setInterval(() => {
  fetchData()
    .then(it => {
      listeners = dropClosed(listeners);
      publish(listeners, it);
    })
    .catch(e => console.error('Could not publish', e));
}, 500);

// set up the server

const server = createServer();
const wsServer = new Server({
  path: '/stream',
  server,
});

server.on('request', app);

wsServer.on('connection', ws => {
  listeners = subscribe(listeners, ws) || [];

  ws.on('close', () => {
    listeners = unsubscribe(listeners, ws) || [];
  });
});

server.listen(port, () => {
  console.log(`Listening on ${port}`);
});

export default server;
