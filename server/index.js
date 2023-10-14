var fs = require('fs');
var http = require('http');
var https = require('https');
const { createHash } = require('crypto');

const ws = require('ws');
const express = require('express');
const basicAuth = require('express-basic-auth')
const { v4: uuidv4 } = require('uuid');
const url = require('url');
const { sortBy, prop } = require('ramda');

const port = process.env.PORT || 8080;
const realm = process.env.REALM || "KuW2i9GdLIkql";
const username = process.env.USERNAME || "admin";
const password = process.env.PASSWORD || "supersecret";
const enableHTTPS = process.env.ENABLE_HTTPS === "true"
const legoPath = process.env.LEGO_PATH
const httpsHostname = process.env.HTTPS_HOSTNAME

const baseOptions = {
  method: 'GET',
  socketPath: '/var/run/docker.sock',
};

const sha1OfData = data =>
  createHash('sha1').update(JSON.stringify(data)).digest('hex');

// Docker API integration

const dockerAPIRequest = path => {
  return new Promise((res, rej) => {
    let buffer = '';

    const r = http.request({ ...baseOptions, path }, response => {
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

// Docker API returns networks in an undefined order, this
// stabilizes the order for effective caching
const stabilize = data => {
  return { ...data, networks: sortBy(prop('Id'), data.networks) };
};

const redact = data => {
  let nodes = [];
  let networks = [];
  let services = [];
  let tasks = [];

  for (let i = 0; i < data.nodes.length; i++) {
    const baseNode = data.nodes[i];
    let node = {
      "ID": baseNode["ID"],
      "Description": {
        "Hostname": baseNode["Description"]["Hostname"],
      },
      "Spec": {
        "Role": baseNode["Spec"]["Role"],
      },
      "Status": {
        "State": baseNode["Status"]["State"],
        "Addr": baseNode["Status"]["Addr"],
      },
    };
    if (baseNode["ManagerStatus"] !== undefined) {
      node["ManagerStatus"] = {
        "Leader": baseNode["ManagerStatus"]["Leader"],
        "Reachability": baseNode["ManagerStatus"]["Reachability"],
      }
    }
    nodes.push(node);
  }

  for (let i = 0; i < data.networks.length; i++) {
    const baseNetwork = data.networks[i];
    let network = {
      "Id": baseNetwork["Id"],
      "Name": baseNetwork["Name"],
      "Ingress": baseNetwork["Ingress"],
    };
    networks.push(network);
  }

  for (let i = 0; i < data.services.length; i++) {
    const baseService = data.services[i];
    let service = {
      "ID": baseService["ID"],
      "Spec": {
        "Name": baseService["Spec"]["Name"],
        "TaskTemplate": {
          "ContainerSpec": {
            "Image": baseService["Spec"]["TaskTemplate"]["ContainerSpec"]["Image"]
          },
        },
      },
    };
    if (baseService["Endpoint"] !== undefined) {
      const _baseVIPs = baseService["Endpoint"]["VirtualIPs"];
      if (_baseVIPs !== undefined && Array.isArray(_baseVIPs) && _baseVIPs.length > 0) {
        let vips = []
        for (let j = 0; j < _baseVIPs.length; j++) {
          const _baseVIP = _baseVIPs[j];
          vips.push({
            "NetworkID": _baseVIP["NetworkID"],
          })
        }
        service["Endpoint"] = {
          "VirtualIPs": vips
        }
      }
    }
    services.push(service);
  }

  for (let i = 0; i < data.tasks.length; i++) {
    const baseTask = data.tasks[i];
    let task = {
      "ID": baseTask["ID"],
      "ServiceID": baseTask["ServiceID"],
      "Status": {
        "Timestamp": baseTask["Status"]["Timestamp"],
        "State": baseTask["Status"]["State"],
      },
      "DesiredState": baseTask["DesiredState"],
      "Spec": {
        "ContainerSpec": {
          "Image": baseTask["Spec"]["ContainerSpec"]["Image"]
        }
      },
    };
    if (baseTask["NodeID"] !== undefined)
      task["NodeID"] = baseTask["NodeID"]
    if (baseTask["Slot"] !== undefined)
      task["Slot"] = baseTask["Slot"]
    tasks.push(task);
  }

  return { nodes, networks, services, tasks };
};

// WebSocket pub-sub

const publish = (listeners, data) => {
  listeners.forEach(listener => {
    if (listener.readyState !== ws.OPEN) return;

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
  return listeners.filter(ws => ws.readyState === ws.OPEN);
};

// set up the application

users = {};
users[username] = password;
const basicAuthConfig = () => basicAuth({
  users: users,
  challenge: true,
  realm: realm,
})
const tokenStore = new Set();

const app = express();

app.use(express.static('client'));
app.get('/_health', (req, res) => res.end());
app.get('/auth_token', basicAuthConfig(), (req, res) => {
  const token = uuidv4();
  tokenStore.add(token);
  res.send(token);
});
// app.get('/data', (req, res) => {
//   fetchData().then(it => res.send(redact(it))).catch(e => res.send(e.toString()));
// });

// start the polling

let listeners = [];
let lastData = {};
let lastSha = '';

setInterval(() => {
  fetchData()
    .then(it => {
      listeners = dropClosed(listeners);

      const data = stabilize(redact(it));
      const sha = sha1OfData(data);

      if (sha == lastSha) return;

      lastSha = sha;
      lastData = data;
      publish(listeners, data);
    })
    .catch(e => console.error('Could not publish', e)); // eslint-disable-line no-console
}, 500);

function onWSConnection(ws, req) {
  let params = undefined;
  let authToken = undefined;
  if (req)
    params = url.parse(req.url, true).query; // { authToken: 'ajsdhakjsdhak' } for 'ws://localhost:1234/?authToken=ajsdhakjsdhak'
  if (params)
    authToken = params.authToken;

  if (tokenStore.has(authToken)) {
    tokenStore.delete(authToken);

    listeners = subscribe(listeners, ws) || [];
    publish([ws], lastData); // immediately send latest to the new listener
    ws.on('close', () => {
      listeners = unsubscribe(listeners, ws) || [];
    });
  } else {
    ws.send("WrongAuthToken");
    setTimeout(() => {
      ws.close(); // terminate this connection
    }, 10000);
  }
}


// set up the server

if (enableHTTPS) {
  const privateKey = fs.readFileSync(legoPath + '/certificates/' + httpsHostname + '.key', 'utf8');
  const certificate = fs.readFileSync(legoPath + '/certificates/' + httpsHostname + '.crt', 'utf8');
  const credentials = { key: privateKey, cert: certificate };

  const httpsServer = https.createServer(credentials);
  httpsServer.on('request', app);
  const wsServer = new ws.Server({
    path: '/stream',
    server: httpsServer,
  });
  wsServer.on('connection', onWSConnection);
  httpsServer.listen(port, () => {
    console.log(`HTTPS server listening on ${port}`); // eslint-disable-line no-console
  });
} else {
  const httpServer = http.createServer();
  httpServer.on('request', app);
  const wsServer = new ws.Server({
    path: '/stream',
    server: httpServer,
  });
  wsServer.on('connection', onWSConnection);
  httpServer.listen(port, () => {
    console.log(`HTTP server listening on ${port}`); // eslint-disable-line no-console
  });
}
