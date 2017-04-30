import express from 'express';
import http from 'http';

const port = process.env.PORT || 8080;
const server = express();

const baseOptions = {
  method: 'GET',
  socketPath: '/var/run/docker.sock'
};

const dockerAPIRequest = path => {
  return new Promise((res, rej) => {
    let buffer = '';

    const request = http.request({ ...baseOptions, path }, response => {
      response.on('data', chunk => (buffer = buffer + chunk));
      response.on('end', () => res(buffer));
    });

    request.on('error', rej);

    request.end();
  });
};

server.use(express.static('client'));

server.get('/data', (req, res) => {
  Promise.all([
    dockerAPIRequest('/nodes').then(JSON.parse),
    dockerAPIRequest('/services').then(JSON.parse),
    dockerAPIRequest('/tasks')
      .then(JSON.parse)
      .then(tasks => tasks.filter(it => it.DesiredState === 'running'))
  ])
    .then(([nodes, services, tasks]) => ({
      nodes,
      services,
      tasks
    }))
    .then(data => res.send(data))
    .catch(e => res.send(e.toString()));
});

server.get('/_health', (req, res) => res.end());
server.listen(port, () => {
  console.log(`Listening on ${port}`);
});

export default server;
