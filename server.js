'use strict';

const ChildProcess = require('child_process');

const Hapi = require('hapi');
const Inert = require('inert');

const YAML = require('yamljs');
const fs = require('fs');
const MD5 = require('md5');

const mkdirp = require('mkdirp');
mkdirp('tex_cache');

require('shelljs/global');

const server = new Hapi.Server();
server.connection({
    port: ~~process.env.PORT || 3000,
    host: '0.0.0.0',
});
server.register(Inert, () => {});


server.route({
  method: 'GET',
  path: '/',
  handler: function(req, reply) {
    reply('texϱbot');
  }
});

server.route({
  method: 'GET',
  path: '/fetch',
  handler: function(req, reply) {
    reply.file('fetcher/index.html');
  }
});

server.route({
    method: 'POST',
    path: '/svg',
    config: {
        cors: {
            origin: ['*'],
            additionalHeaders: ['cache-control', 'x-requested-with']
        },
        handler: function(req, reply) {

            console.log(req);

            console.log(req.payload);

            var yaml = YAML.stringify(req.payload);
            var hash = MD5(yaml);

            fs.writeFileSync(
                `tex_cache/${hash}.yml`,
                `---\n${yaml}...`
            );

            exec(`pandoc ${hash}.yml --template=../template.tex`
                +` --output=${hash}.tex`,{cwd: 'tex_cache'});
            exec(`latex ${hash}.tex`,{cwd: 'tex_cache'});
            exec(`dvisvgm ${hash}.dvi --no-fonts`,{cwd: 'tex_cache'});
            reply.file(`tex_cache/${hash}.svg`);






        }
  // , validate: {
      // payload: {
        // author: Hapi.types.String().required()
      // , text: Hapi.types.String().required()
      // }
    // }
  }
});

// Start the server
server.start((err) => {
    if (err) {
        throw err;
    }
    console.log('Server running at:', server.info.uri);
});
