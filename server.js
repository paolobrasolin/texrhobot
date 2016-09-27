'use strict';

const ChildProcess = require('child_process');

const Hapi = require('hapi');
const Inert = require('inert');

const YAML = require('yamljs');
const fs = require('fs');
const MD5 = require('md5');

const mkdirp = require('mkdirp');
mkdirp('tex_cache');

const server = new Hapi.Server();
server.connection({
    port: ~~process.env.PORT || 3000,
    host: '0.0.0.0'
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
    method: 'POST',
    path: '/pdf',
    config: {
        handler: function(req, reply) {

            var yaml = YAML.stringify(req.payload);
            var hash = MD5(yaml);

            fs.writeFile(
                `tex_cache/${hash}.yml`,
                `---\n${yaml}...`,
                function (err, data){}
            );

            var pandoc = ChildProcess.spawn('pandoc', [
                `tex_cache/${hash}.yml`,
                '--template=template.tex',
                `--output=tex_cache/${hash}.tex`
            ]);

            // pandoc.stdout.on('data', (data) => {
                // console.log(`stdout: ${data}`);
            // });

            // pandoc.stderr.on('data', (data) => {
                // console.log(`stderr: ${data}`);
            // });

            var latex = ChildProcess.spawn('latex', [
                `${hash}.tex`,
            ], {
                cwd: 'tex_cache'
            });

            // latex.stdout.on('data', (data) => {
                // console.log(`stdout: ${data}`);
            // });

            // latex.stderr.on('data', (data) => {
                // console.log(`stderr: ${data}`);
            // });

            var dvisvgm = ChildProcess.spawn('dvisvgm', [
                `${hash}.dvi`,
                '--no-fonts'
                // '--zip'
            ], {
                cwd: 'tex_cache'
            });

            // dvisvgm.stdout.on('data', (data) => {
                // console.log(`stdout: ${data}`);
            // });

            // dvisvgm.stderr.on('data', (data) => {
                // console.log(`stderr: ${data}`);
            // });

            pandoc.on('close', (code) => {
                console.log(`pandoc exited with code ${code}`);
                    latex.on('close', (code) => {
                        console.log(`latex exited with code ${code}`);
                            dvisvgm.on('close', (code) => {
                                console.log(`dvisvgm exited with code ${code}`);
                                reply.file(`tex_cache/${hash}.svg`);
                            });
                    });
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
