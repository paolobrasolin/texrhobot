'use strict';

const ChildProcess = require('child_process');

const Hapi = require('hapi');
const Inert = require('inert');

const YAML = require('yamljs');
const fs = require('fs');



const server = new Hapi.Server();
server.connection({
    port: ~~process.env.PORT || 3000,
    host: '0.0.0.0'
});
server.register(Inert, () => {});


server.route({
  method: 'GET'
, path: '/'
, handler: function(req, reply) {
    reply("hello world");
  }
});

server.route({
    method: 'POST',
    path: '/pdf',
    config: {
        handler: function(req, reply) {

            var yaml = YAML.stringify(req.payload);
            fs.writeFile('metadata.yaml', `---\n${yaml}...`, function (err, data){});

            var ls = ChildProcess.spawn('pandoc', [
                'metadata.yaml',
                '--template=template.tex',
                '--output=test.pdf'
            ]);

            ls.stdout.on('data', (data) => {
            console.log(`stdout: ${data}`);
            });

            ls.stderr.on('data', (data) => {
            console.log(`stderr: ${data}`);
            });

            ls.on('close', (code) => {
                console.log(`child process exited with code ${code}`);
                reply.file("test.pdf");

            });

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
