server.log("agent started on " + http.agenturl());
http.onrequest(function(req, res) {
    server.log(req.path);
    if (req.path == "/red") {
        device.send("color", "red");
    } else if (req.path == "/green") {
        device.send("color", "blue");
    } else if (req.path == "/blue") {
        device.send("color", "green");
    }
    
    res.send(200, "Moo");
});
