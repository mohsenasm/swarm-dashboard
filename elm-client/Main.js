import React, { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { useLocation } from 'react-router-dom';
import { groupBy } from './Util';
import { fromJson } from './Docker';
import { SwarmGrid } from './Components';

const localWebsocket = (location) => {
  if (typeof window === 'undefined') return '';
  return location.protocol === 'https:'
    ? `wss://localhost:8080/stream`
    : `ws://localhost:8080/stream`;
  // ? `wss://${location.host}${location.pathname}stream`
  // : `ws://${location.host}${location.pathname}stream`;
};

const App = () => {
  const location = useLocation();
  const [model, setModel] = useState({
    pathname: location.pathname,
    webSocketUrl: localWebsocket(location),
    authToken: '',
    swarm: { services: [], nodes: [], networks: [], assignedTasks: [], refreshTime: '' },
    tasks: {},
    errors: []
  });

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const fetchAuthToken = async () => {
      try {
        const response = await fetch(`http://localhost:8080/auth_token`);
        // const response = await fetch(`${location.pathname}auth_token`);
        if (response.ok) {
          const authToken = await response.text();
          setModel((prevModel) => ({ ...prevModel, authToken }));
        } else {
          const errorMessage = `Error in fetching auth_token: ${response.status} ${response.statusText}`;
          setModel((prevModel) => ({ ...prevModel, errors: [...prevModel.errors, errorMessage] }));
        }
      } catch (error) {
        setModel((prevModel) => ({ ...prevModel, errors: [...prevModel.errors, error.toString()] }));
      }
    };

    fetchAuthToken();
  }, [location.pathname]);

  useEffect(() => {
    if (!model.authToken || typeof window === 'undefined') return;

    const ws = new WebSocket(`${model.webSocketUrl}?authToken=${model.authToken}`);
    ws.onmessage = (event) => {
      const serverJson = event.data;
      
      const result = fromJson(serverJson);
      if (result.ok) {
        setModel((prevModel) => ({
          ...prevModel,
          swarm: result.data,
          tasks: groupBy((task) => [task.nodeId, task.serviceId], result.data.assignedTasks)
        }));
      } else {
        if (result.error.includes('WrongAuthToken')) {
          fetchAuthToken();
        } else {
          setModel((prevModel) => ({ ...prevModel, errors: [...prevModel.errors, result.error] }));
        }
      }
    };

    return () => ws.close();
  }, [model.authToken, model.webSocketUrl]);

  const { swarm, tasks, errors } = model;
  const { services, nodes, networks, refreshTime } = swarm;

  return (
    <div>
      <SwarmGrid services={services} nodes={nodes} networks={networks} tasks={tasks} refreshTime={refreshTime} />
      <ul>
        {errors.map((error, index) => (
          <li key={index}>{error}</li>
        ))}
      </ul>
    </div>
  );
};

const DynamicBrowserRouter = dynamic(() => import('react-router-dom').then((mod) => mod.BrowserRouter), { ssr: false });

const Main = () => (
  <DynamicBrowserRouter>
    <App />
  </DynamicBrowserRouter>
);

export default Main;
