// Local fixture server for the real Godot HTTP client.
const http = require('http'), fs = require('fs'), path = require('path');
const root = process.env.RALPH_UPDATE_FIXTURES || path.resolve(__dirname, '../../../validation/update-fixtures/http');
http.createServer((req, res) => {
 if(req.method !== 'GET'){res.writeHead(501);res.end('Not modeled');return;}
 let p = new URL(req.url, 'http://localhost').pathname.replace(/^\/updates\//, '/');
 if(p.startsWith('/html-error/')){res.writeHead(503,{'Content-Type':'text/html'});res.end('<h1>Unavailable</h1>');return;}
 if(p.startsWith('/timeout/')){setTimeout(()=>{res.writeHead(503);res.end('late');},3000);return;}
 if(p.includes('..') || p.includes('%')){res.writeHead(400);res.end();return;}
 const file=path.resolve(root,'.'+p);
 if(!file.startsWith(path.resolve(root)+path.sep)||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 const size=fs.statSync(file).size;
 res.writeHead(200,{'Content-Type':file.endsWith('.zip')?'application/zip':'application/json','Content-Length':size,'Cache-Control':'no-cache'});
 fs.createReadStream(file).pipe(res);
}).listen(process.env.PORT||4937,'127.0.0.1');
