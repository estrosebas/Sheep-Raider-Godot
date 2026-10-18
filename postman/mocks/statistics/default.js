// Minimal local stand-in from statistics.openapi.yaml for the real Godot client.
const http = require('http');
http.createServer((req,res)=>{
  if(req.method!=='POST'||!req.url.endsWith('/stats/events')){res.writeHead(501);res.end();return;}
  let body='';req.on('data',chunk=>{body+=chunk;});
  req.on('end',()=>{
    let valid=false;
    try{const x=JSON.parse(body);valid=x.kind==='session'&&['windows','android','web'].includes(x.platform)&&x.consent==='v1'&&/^[a-f0-9]{32}$/.test(x.event);}catch(_){}
    res.writeHead(valid?202:400,{'Content-Type':'application/json'});
    res.end(JSON.stringify(valid?{accepted:true}:{error:'invalid_event'}));
  });
}).listen(process.env.PORT||4940,'127.0.0.1');
