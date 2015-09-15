var app = require('express')();
var http = require('http').Server(app);
var port = 3000;
var io = require('socket.io')(port);

/*
app.get('/', function(req, res){
  res.sendfile('index.html');
});
*/


io.on('connection', function(socket){
	console.log('connection');
	socket.on('data', function(data) {
		console.log(data);
	});
  socket.on('disconnect', function(){
  	console.log('disconnect');
  });	
});

/*
var net = require('net');
var server = net.createServer(function(c) { //'connection' listener
  console.log('client connected');
  c.on('end', function() {
    console.log('client disconnected');
  });
  c.write('hello\r\n');
  c.pipe(c);
});
server.listen(8080, function() { //'listening' listener
  console.log('server bound');
});
*/